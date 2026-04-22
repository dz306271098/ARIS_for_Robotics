#Requires -Version 5.1
<#
.SYNOPSIS
    ARIS skill installation on Windows via flat per-skill junctions + manifest tracking.

.DESCRIPTION
    Creates one junction per ARIS skill under the install root's skills directory.
    A versioned manifest at <install-root>\.aris\installed-skills.txt tracks every
    entry this installer created — uninstall/reconcile read from the manifest and
    NEVER touch user-owned skills that happen to share a name.

    Two install modes:
      -Global (default):  install into %USERPROFILE%\.claude\skills\
                          (one install serves every Claude Code project on the machine)
      -Project [PATH]:    install into <PATH>\.claude\skills\
                          (visible only to Claude Code sessions in that project)

    Each skill is a junction to <aris-repo>\skills\<skill-name>.

.PARAMETER Global
    Install globally to %USERPROFILE%\.claude\skills\. DEFAULT.

.PARAMETER Project
    Install locally. If a path is supplied, uses it; otherwise uses CWD.

.PARAMETER ProjectPath
    Path for -Project mode. Alternative to inline arg.

.PARAMETER ArisRepo
    Override path to ARIS repo. Defaults to auto-detect.

.PARAMETER Uninstall
    Remove every symlink/junction listed in the manifest. Safe: won't touch
    real files or user-owned symlinks.

.PARAMETER Reconcile
    Resync against upstream. Requires existing manifest. Adds new skills, removes
    skills no longer in upstream.

.PARAMETER DryRun
    Print plan without making changes.

.PARAMETER Quiet
    No prompts; abort on any condition that would prompt.

.PARAMETER NoDoc
    Skip CLAUDE.md update (project-local mode only).

.PARAMETER AdoptExisting
    Comma-separated skill names to adopt if they're non-managed junctions pointing
    to the correct upstream target.

.PARAMETER ReplaceLink
    Comma-separated skill names to replace if they're managed junctions pointing
    to a different target than expected.

.EXAMPLE
    .\tools\install_aris.ps1                                    # Global install
    .\tools\install_aris.ps1 -Project                           # Project (CWD)
    .\tools\install_aris.ps1 -Project C:\my-paper               # Project (explicit)
    .\tools\install_aris.ps1 -Uninstall                         # Uninstall global
    .\tools\install_aris.ps1 -DryRun                            # Show plan only
    .\tools\install_aris.ps1 -Reconcile                         # Resync manifest

.NOTES
    Safety rules (match install_aris.sh):
      S1  Never delete a path that is not a symlink/junction.
      S2  Never delete a symlink/junction whose target is outside the aris-repo.
      S3  Never delete a symlink/junction not listed in the manifest (except --Uninstall).
      S4  Never overwrite an existing path during CREATE.
      S5  Manifest write is atomic (temp + rename).
      S6  Concurrent runs in same install-root serialize via lock dir.
      S9  Refuse if .aris/.claude/.claude\skills/ is itself a junction.
      S13 Skill names must match ^[A-Za-z0-9][A-Za-z0-9._-]*$

    Windows junction notes: junctions work without admin rights (unlike symbolic
    links on older Windows). Test-Path follows junctions, so the script uses
    Get-Item -Force to inspect the link itself.
#>

[CmdletBinding(DefaultParameterSetName = 'Global')]
param(
    [Parameter(ParameterSetName = 'Global')]
    [switch]$Global,

    [Parameter(ParameterSetName = 'Project')]
    [switch]$Project,

    [Parameter(ParameterSetName = 'Project', Position = 0)]
    [string]$ProjectPath = '',

    [string]$ArisRepo = '',
    [switch]$Uninstall,
    [switch]$Reconcile,
    [switch]$DryRun,
    [switch]$Quiet,
    [switch]$NoDoc,
    [string[]]$AdoptExisting = @(),
    [string[]]$ReplaceLink = @()
)

$ErrorActionPreference = 'Stop'

# ─── Constants ────────────────────────────────────────────────────────────────
$ManifestVersion   = '1'
$ManifestName      = 'installed-skills.txt'
$ManifestPrevName  = 'installed-skills.txt.prev'
$ArisDirName       = '.aris'
$LockDirName       = '.install.lock.d'
$SkillsRel         = '.claude\skills'
$DocFileName       = 'CLAUDE.md'
$BlockBegin        = '<!-- ARIS:BEGIN -->'
$BlockEnd          = '<!-- ARIS:END -->'
$SafeNameRegex     = '^[A-Za-z0-9][A-Za-z0-9._-]*$'
$SupportNames      = @('shared-references')
$ExcludeTopNames   = @('skills-codex', 'skills-codex-claude-review', 'skills-codex-gemini-review', 'skills-codex.bak')

# ─── Mode resolution ──────────────────────────────────────────────────────────
if ($PSCmdlet.ParameterSetName -eq 'Project') {
    $InstallMode = 'project'
    if (-not $ProjectPath) { $ProjectPath = (Get-Location).Path }
} else {
    $InstallMode = 'global'
}

# ─── Helpers ──────────────────────────────────────────────────────────────────
function Write-Log { param($Msg) if (-not $Quiet) { Write-Host $Msg } }
function Write-Warn { param($Msg) Write-Host "warning: $Msg" -ForegroundColor Yellow }
function Die { param($Msg) Write-Host "error: $Msg" -ForegroundColor Red; exit 1 }
function Is-SafeName { param($Name) $Name -match $SafeNameRegex }

function Get-LinkTarget {
    param($Path)
    $item = Get-Item $Path -Force -ErrorAction SilentlyContinue
    if ($null -eq $item) { return $null }
    if ($item.LinkType -in @('Junction', 'SymbolicLink')) {
        $tgt = $item.Target
        if ($tgt -is [array]) { return $tgt[0] }
        return $tgt
    }
    return $null
}

function Is-Link { param($Path) $null -ne (Get-LinkTarget $Path) }

# ─── Resolve install root ─────────────────────────────────────────────────────
switch ($InstallMode) {
    'global' {
        $ClaudeHome = if ($env:CLAUDE_HOME) { $env:CLAUDE_HOME } else { Join-Path $env:USERPROFILE '.claude' }
        $InstallRoot = $ClaudeHome
        if (-not (Test-Path $InstallRoot)) { New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null }
        $InstallRoot = (Resolve-Path $InstallRoot).Path
        $InstallSkillsDir = Join-Path $InstallRoot 'skills'
        $InstallArisDir = Join-Path $InstallRoot $ArisDirName
    }
    'project' {
        if (-not (Test-Path $ProjectPath -PathType Container)) { Die "project path does not exist: $ProjectPath" }
        $InstallRoot = (Resolve-Path $ProjectPath).Path
        $InstallSkillsDir = Join-Path $InstallRoot $SkillsRel
        $InstallArisDir = Join-Path $InstallRoot $ArisDirName
    }
}

$ManifestPath = Join-Path $InstallArisDir $ManifestName
$ManifestPrev = Join-Path $InstallArisDir $ManifestPrevName
$LockDir = Join-Path $InstallArisDir $LockDirName
$DocFile = Join-Path $InstallRoot $DocFileName

# ─── Resolve ARIS repo ────────────────────────────────────────────────────────
function Resolve-ArisRepo {
    if ($ArisRepo) {
        if (Test-Path (Join-Path $ArisRepo 'skills')) { return (Resolve-Path $ArisRepo).Path }
        Die "-ArisRepo path has no skills\ subdir: $ArisRepo"
    }
    $parent = Split-Path $PSScriptRoot -Parent
    if (Test-Path (Join-Path $parent 'skills')) { return $parent }
    if ($env:ARIS_REPO -and (Test-Path (Join-Path $env:ARIS_REPO 'skills'))) {
        return (Resolve-Path $env:ARIS_REPO).Path
    }
    foreach ($p in @(
        (Join-Path $env:USERPROFILE 'Music\Auto-claude-code-research-in-sleep'),
        (Join-Path $env:USERPROFILE 'Desktop\Auto-claude-code-research-in-sleep'),
        (Join-Path $env:USERPROFILE 'aris_repo'),
        (Join-Path $env:USERPROFILE '.aris')
    )) {
        if (Test-Path (Join-Path $p 'skills')) { return $p }
    }
    Die "cannot find ARIS repo. Use -ArisRepo PATH or set `$env:ARIS_REPO env var."
}

$ArisRepoResolved = Resolve-ArisRepo
$SkillsDirAbs = Join-Path $ArisRepoResolved 'skills'

# ─── S9: refuse if critical dirs are junctions ────────────────────────────────
function Check-NoSymlinkedParents {
    foreach ($p in @($InstallArisDir, (Join-Path $InstallRoot '.claude'), $InstallSkillsDir)) {
        if (Test-Path $p) {
            $item = Get-Item $p -Force
            if ($item.LinkType -in @('Junction', 'SymbolicLink')) {
                Die "S9: $p is a junction/symlink — refusing to install (would mutate target)"
            }
        }
    }
}

# ─── Lock acquisition ─────────────────────────────────────────────────────────
function Acquire-Lock {
    New-Item -ItemType Directory -Force -Path $InstallArisDir | Out-Null
    if (-not (Test-Path $LockDir)) {
        try {
            New-Item -ItemType Directory -Path $LockDir -ErrorAction Stop | Out-Null
            @{
                host       = $env:COMPUTERNAME
                pid        = $PID
                started_at = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
                tool       = 'install_aris.ps1'
                mode       = $InstallMode
            } | ConvertTo-Json | Out-File (Join-Path $LockDir 'owner.json') -Encoding utf8
            $PID | Out-File (Join-Path $LockDir 'owner.pid') -Encoding utf8
            return
        } catch {
            $owner = ''
            if (Test-Path (Join-Path $LockDir 'owner.json')) { $owner = Get-Content (Join-Path $LockDir 'owner.json') -Raw }
            Die "another install_aris is running for this install root`n       lock: $LockDir`n       owner: $owner"
        }
    }
    $owner = ''
    if (Test-Path (Join-Path $LockDir 'owner.json')) { $owner = Get-Content (Join-Path $LockDir 'owner.json') -Raw }
    Die "another install_aris is running for this install root`n       lock: $LockDir`n       owner: $owner"
}

function Release-Lock {
    if (Test-Path $LockDir) {
        $pidFile = Join-Path $LockDir 'owner.pid'
        if (Test-Path $pidFile) {
            $lockPid = (Get-Content $pidFile -Raw).Trim()
            if ($lockPid -eq $PID) {
                Remove-Item -Recurse -Force $LockDir -ErrorAction SilentlyContinue
            }
        }
    }
}

# ─── Inventory upstream ───────────────────────────────────────────────────────
function Build-UpstreamInventory {
    $entries = @()
    Get-ChildItem $SkillsDirAbs -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $name = $_.Name
        if (-not (Is-SafeName $name)) { Write-Warn "skipping unsafe upstream name: $name"; return }
        if ($ExcludeTopNames -contains $name) { return }
        if ($SupportNames -contains $name) { return }  # handled below
        if (-not (Test-Path (Join-Path $_.FullName 'SKILL.md'))) { return }
        $entries += "skill|$name"
    }
    foreach ($s in $SupportNames) {
        if (Test-Path (Join-Path $SkillsDirAbs $s) -PathType Container) {
            $entries += "support|$s"
        }
    }
    $entries
}

# ─── Manifest I/O ─────────────────────────────────────────────────────────────
function Load-Manifest {
    param($Path)
    if (-not (Test-Path $Path)) { return @() }
    $lines = Get-Content $Path
    $verLine = $lines | Where-Object { $_ -match '^version\t(.+)$' } | Select-Object -First 1
    if ($verLine -match '^version\t(.+)$') {
        if ($matches[1] -ne $ManifestVersion) {
            Die "manifest version mismatch (file: $($matches[1]), expected: $ManifestVersion)"
        }
    }
    $inBody = $false
    $body = @()
    foreach ($line in $lines) {
        if ($line -eq "kind`tname`tsource_rel`ttarget_rel`tmode") { $inBody = $true; continue }
        if ($inBody -and $line.Split("`t").Count -eq 5) { $body += $line }
    }
    $body
}

function Manifest-LookupTarget {
    param($Data, $Name)
    foreach ($line in $Data) {
        $cols = $line.Split("`t")
        if ($cols[1] -eq $Name) { return $cols[3] }
    }
    $null
}

# ─── Plan computation ─────────────────────────────────────────────────────────
function Compute-Plan {
    param($Upstream, $ManifestData)
    $plan = @()
    foreach ($entry in $Upstream) {
        $cols = $entry.Split('|')
        $kind, $name = $cols[0], $cols[1]
        $targetPath = Join-Path $InstallSkillsDir $name
        $expectedTarget = Join-Path $SkillsDirAbs $name

        if (Is-Link $targetPath) {
            $currentTarget = Get-LinkTarget $targetPath
            $inManifest = $null -ne (Manifest-LookupTarget $ManifestData $name)
            if ($currentTarget -eq $expectedTarget) {
                $plan += if ($inManifest) { "REUSE|$kind|$name|" } else { "ADOPT|$kind|$name|" }
            } else {
                $plan += if ($inManifest) { "UPDATE_TARGET|$kind|$name|$currentTarget" } else { "CONFLICT|$kind|$name|link_to:$currentTarget" }
            }
        } elseif (Test-Path $targetPath) {
            $plan += "CONFLICT|$kind|$name|real_path"
        } else {
            $plan += "CREATE|$kind|$name|"
        }
    }
    $upstreamNames = $Upstream | ForEach-Object { ($_.Split('|'))[1] }
    foreach ($line in $ManifestData) {
        $cols = $line.Split("`t")
        $mname = $cols[1]; $mkind = $cols[0]
        if (-not ($upstreamNames -contains $mname)) {
            $plan += "REMOVE|$mkind|$mname|"
        }
    }
    $plan
}

function Print-Plan {
    param($Plan)
    $counts = @{}
    foreach ($actions in 'CREATE', 'UPDATE_TARGET', 'REUSE', 'REMOVE', 'ADOPT', 'CONFLICT') {
        $counts[$actions] = ($Plan | Where-Object { $_ -match "^$actions\|" }).Count
    }
    Write-Log ""
    Write-Log "Plan summary:"
    Write-Log "  CREATE:        $($counts.CREATE)  (new junctions to add)"
    Write-Log "  ADOPT:         $($counts.ADOPT)   (orphan junctions already pointing to correct target)"
    Write-Log "  UPDATE_TARGET: $($counts.UPDATE_TARGET)  (managed junctions with stale target)"
    Write-Log "  REUSE:         $($counts.REUSE)   (already correct, no-op)"
    Write-Log "  REMOVE:        $($counts.REMOVE)  (in old manifest, no longer upstream)"
    Write-Log "  CONFLICT:      $($counts.CONFLICT)  (must be resolved before apply)"
    if ($counts.CONFLICT -gt 0) {
        Write-Log ""
        Write-Log "Conflicts (need user action):"
        $Plan | Where-Object { $_ -match '^CONFLICT\|' } | ForEach-Object {
            $cols = $_.Split('|')
            Write-Log "  - $($cols[2]) ($($cols[1])): $($cols[3])"
        }
    }
    $counts
}

# ─── Apply ────────────────────────────────────────────────────────────────────
function Apply-Plan {
    param($Plan)
    if (-not (Test-Path $InstallSkillsDir)) { New-Item -ItemType Directory -Force -Path $InstallSkillsDir | Out-Null }
    foreach ($line in $Plan) {
        $cols = $line.Split('|')
        $action = $cols[0]; $kind = $cols[1]; $name = $cols[2]; $extra = $cols[3]
        $targetPath = Join-Path $InstallSkillsDir $name
        $expectedTarget = Join-Path $SkillsDirAbs $name
        switch ($action) {
            { $_ -in 'REUSE', 'ADOPT' } { }
            'CREATE' {
                if (Test-Path $targetPath) { Die "S4: $targetPath appeared between plan and apply" }
                if ($DryRun) { Write-Log "  (dry-run) junction $targetPath -> $expectedTarget" }
                else {
                    New-Item -ItemType Junction -Path $targetPath -Target $expectedTarget | Out-Null
                    Write-Log "  + $name"
                }
            }
            'UPDATE_TARGET' {
                $current = Get-LinkTarget $targetPath
                if ($current -ne $extra) { Write-Warn "S11: $targetPath target changed since plan — skipping"; continue }
                if (-not $current.StartsWith($ArisRepoResolved)) { Write-Warn "S2: refusing to replace junction pointing outside aris-repo"; continue }
                if ($DryRun) { Write-Log "  (dry-run) update: $targetPath -> $expectedTarget" }
                else {
                    Remove-Item $targetPath -Force
                    New-Item -ItemType Junction -Path $targetPath -Target $expectedTarget | Out-Null
                    Write-Log "  ↻ $name"
                }
            }
            'REMOVE' {
                if (-not (Is-Link $targetPath)) { Write-Warn "S1: $targetPath is not a junction, refusing to remove"; continue }
                $current = Get-LinkTarget $targetPath
                if (-not $current.StartsWith($ArisRepoResolved)) { Write-Warn "S2: target outside aris-repo, refusing"; continue }
                if ($DryRun) { Write-Log "  (dry-run) rm $targetPath" }
                else { Remove-Item $targetPath -Force; Write-Log "  - $name" }
            }
            'CONFLICT' { Die "BUG: CONFLICT $name reached apply phase" }
        }
    }
}

function Write-ManifestTmp {
    param($Plan, $OutPath)
    $lines = @()
    $lines += "version`t$ManifestVersion"
    $lines += "repo_root`t$ArisRepoResolved"
    $lines += "install_mode`t$InstallMode"
    $lines += "install_root`t$InstallRoot"
    $lines += "generated`t$((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))"
    $lines += "kind`tname`tsource_rel`ttarget_rel`tmode"
    foreach ($line in $Plan) {
        $cols = $line.Split('|')
        $action = $cols[0]
        if ($action -in 'REUSE', 'ADOPT', 'CREATE', 'UPDATE_TARGET') {
            $name = $cols[2]; $kind = $cols[1]
            $tgtRel = if ($InstallMode -eq 'global') { "skills\$name" } else { "$SkillsRel\$name" }
            $lines += "$kind`t$name`tskills\$name`t$tgtRel`tjunction"
        }
    }
    $lines -join "`n" | Out-File -FilePath $OutPath -Encoding utf8 -NoNewline
}

function Commit-Manifest {
    param($TmpPath)
    if ($DryRun) { Write-Log "  (dry-run) would commit manifest"; return }
    if (Test-Path $ManifestPath) {
        Copy-Item $ManifestPath "$ManifestPrev.tmp" -Force
        Move-Item "$ManifestPrev.tmp" $ManifestPrev -Force
    }
    Move-Item $TmpPath $ManifestPath -Force
}

# ─── Uninstall ────────────────────────────────────────────────────────────────
function Do-Uninstall {
    if (-not (Test-Path $ManifestPath)) { Die "no manifest at $ManifestPath; nothing to uninstall" }
    $data = Load-Manifest $ManifestPath
    Write-Log ""
    Write-Log "Uninstall plan ($InstallMode mode, root: $InstallRoot):"
    foreach ($line in $data) {
        $cols = $line.Split("`t")
        Write-Log "  - $($cols[1]) ($($cols[0]))"
    }
    if (-not $DryRun -and -not $Quiet) {
        $reply = Read-Host "Proceed? [y/N]"
        if ($reply -notmatch '^[Yy]$') { Write-Log "aborted"; exit 0 }
    }
    foreach ($line in $data) {
        $cols = $line.Split("`t")
        $name = $cols[1]; $target = $cols[3]
        $targetPath = Join-Path $InstallRoot $target
        $expected = Join-Path $SkillsDirAbs $name
        if (-not (Is-Link $targetPath)) { Write-Warn "S1: $targetPath not a junction, skipping"; continue }
        $cur = Get-LinkTarget $targetPath
        if ($cur -ne $expected) { Write-Warn "S8: target $cur != expected $expected, skipping"; continue }
        if ($DryRun) { Write-Log "  (dry-run) rm $targetPath" }
        else { Remove-Item $targetPath -Force; Write-Log "  - removed $name" }
    }
    if (-not $DryRun -and (Test-Path $ManifestPath)) {
        Move-Item $ManifestPath $ManifestPrev -Force
        Write-Log "  ✓ uninstalled (manifest preserved as $ManifestPrev for forensics)"
    }
}

# ─── Main ─────────────────────────────────────────────────────────────────────
Write-Log ""
Write-Log "ARIS Install"
Write-Log "  Mode:         $InstallMode"
Write-Log "  Install root: $InstallRoot"
Write-Log "  Skills dir:   $InstallSkillsDir"
Write-Log "  ARIS repo:    $ArisRepoResolved"
$action = if ($Uninstall) { 'uninstall' } elseif ($Reconcile) { 'reconcile' } else { 'auto' }
Write-Log "  Action:       $action$(if ($DryRun) { ' (dry-run)' })"
Write-Log ""

Check-NoSymlinkedParents
Acquire-Lock
try {
    if ($Uninstall) {
        Do-Uninstall
        exit 0
    }

    if ($Reconcile -and -not (Test-Path $ManifestPath)) {
        Die "-Reconcile requires existing manifest; none found at $ManifestPath"
    }

    $upstream = Build-UpstreamInventory
    if ($upstream.Count -eq 0) { Die "upstream inventory empty (broken aris-repo?)" }

    $manifestData = Load-Manifest $ManifestPath

    $plan = Compute-Plan $upstream $manifestData
    $counts = Print-Plan $plan

    if ($counts.CONFLICT -gt 0) {
        if ($ReplaceLink.Count -gt 0) {
            for ($i = 0; $i -lt $plan.Count; $i++) {
                foreach ($n in $ReplaceLink) {
                    if ($plan[$i] -match "^CONFLICT\|[^|]+\|$([regex]::Escape($n))\|") {
                        $plan[$i] = $plan[$i] -replace '^CONFLICT\|', 'UPDATE_TARGET|'
                    }
                }
            }
            $counts.CONFLICT = ($plan | Where-Object { $_ -match '^CONFLICT\|' }).Count
        }
        if ($counts.CONFLICT -gt 0) {
            Write-Log ""
            Write-Log "Aborting due to $($counts.CONFLICT) unresolved conflicts."
            Write-Log "Resolve options:"
            Write-Log "  - back up & remove the conflicting path manually, then rerun"
            Write-Log "  - if it's a foreign junction to be replaced: -ReplaceLink NAME1,NAME2"
            exit 1
        }
    }

    if ($DryRun) {
        Write-Log ""
        Write-Log "(dry-run) no changes made"
        exit 0
    }

    $nChanges = ($plan | Where-Object { $_ -match '^(CREATE|UPDATE_TARGET|REMOVE)\|' }).Count
    if ($nChanges -gt 0 -and -not $Quiet) {
        $reply = Read-Host "Apply these $nChanges changes? [y/N]"
        if ($reply -notmatch '^[Yy]$') { Write-Log "aborted"; exit 0 }
    }

    $manifestTmp = "$ManifestPath.tmp.$PID"
    New-Item -ItemType Directory -Force -Path $InstallArisDir | Out-Null
    Write-ManifestTmp $plan $manifestTmp
    Write-Log ""
    Write-Log "Applying:"
    Apply-Plan $plan
    Commit-Manifest $manifestTmp

    Write-Log ""
    Write-Log "✓ Install complete. $nChanges changes applied."
} finally {
    Release-Lock
}
