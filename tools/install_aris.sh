#!/usr/bin/env bash
# install_aris.sh — ARIS skill installation via per-skill symlinks + manifest tracking.
#
# Two install modes:
#   --global (default)  install into `~/.claude/skills/<skill-name>` (or $CLAUDE_HOME/skills/)
#                       one install serves every Claude Code project on the machine.
#   --project [PATH]    install into `<PATH>/.claude/skills/<skill-name>` (default: cwd)
#                       one install is visible only to Claude Code sessions in that project.
#
# Each skill is symlinked to `<aris-repo>/skills/<skill-name>`. A versioned
# manifest at `<install-root>/.aris/installed-skills.txt` tracks every entry
# this installer created — uninstall and reconcile read from the manifest and
# NEVER touch user-owned skills that happen to share a name.
#
# Usage:
#   bash tools/install_aris.sh [options]                        # global install (default)
#   bash tools/install_aris.sh --project                        # project-local (cwd)
#   bash tools/install_aris.sh --project /path/to/project       # project-local (explicit)
#   bash tools/install_aris.sh --uninstall                      # uninstall (uses manifest)
#   bash tools/install_aris.sh --reconcile                      # resync against upstream
#   bash tools/install_aris.sh --dry-run                        # show plan, no writes
#
# Actions (mutually exclusive, default: auto):
#   default          install if no manifest, else reconcile
#   --reconcile      explicit reconcile; refuse if no manifest
#   --uninstall      remove only entries in manifest; delete manifest
#
# Mode options:
#   --global               install to ~/.claude/skills/ (DEFAULT)
#   --project [PATH]       install to <PATH>/.claude/skills/ (default PATH = cwd)
#
# Other options:
#   --aris-repo PATH       override aris-repo discovery (where the ARIS source lives)
#   --dry-run              show plan, no writes
#   --quiet                no prompts; abort on any condition that would prompt
#   --no-doc               skip CLAUDE.md update (project-local mode only)
#   --adopt-existing NAME  adopt a non-managed symlink that already points to the
#                          correct upstream target (repeatable)
#   --replace-link NAME    replace a managed symlink that points to a DIFFERENT
#                          entry than expected (repeatable)
#   --from-old             trigger migration from legacy nested install
#                          (.claude/skills/aris/)
#   --migrate-copy STRAT   for legacy COPY install: STRAT = keep-user | prefer-upstream
#                          (default: refuse)
#   --clear-stale-lock     remove stale lock dir from a crashed prior run
#                          (host+PID metadata is verified before removal)
#
# Safety rules enforced:
#   S1  Never delete a path that is not a symlink.
#   S2  Never delete a symlink whose target is outside the configured aris-repo.
#   S3  Never delete a symlink not listed in the manifest (except via --uninstall
#       which only deletes manifest entries).
#   S4  Never overwrite an existing path during CREATE — abort by default.
#   S5  Manifest write is atomic (temp + rename in same dir).
#   S6  Concurrent runs in same install-root serialize via mkdir lockdir.
#   S7  Crash mid-apply leaves the previous manifest intact; rerun adopts.
#   S8  Uninstall revalidates each managed symlink's target before removing.
#   S9  If .aris/, .claude/, or .claude/skills/ is itself a symlink, abort.
#   S10 Reject upstream entries that are symlinks to outside aris-repo.
#   S11 Revalidate exact target match (lstat + readlink) before every mutation.
#   S12 Temp files live in the same directory as the destination.
#   S13 Skill names must match ^[A-Za-z0-9][A-Za-z0-9._-]*$ (slug regex).

set -euo pipefail

# ─── Constants ────────────────────────────────────────────────────────────────
MANIFEST_VERSION="1"
MANIFEST_NAME="installed-skills.txt"
MANIFEST_PREV_NAME="installed-skills.txt.prev"
ARIS_DIR_NAME=".aris"
LOCK_DIR_NAME=".install.lock.d"
SKILLS_REL=".claude/skills"
DOC_FILE_NAME="CLAUDE.md"
BLOCK_BEGIN="<!-- ARIS:BEGIN -->"
BLOCK_END="<!-- ARIS:END -->"
SAFE_NAME_REGEX='^[A-Za-z0-9][A-Za-z0-9._-]*$'
SUPPORT_NAMES=("shared-references")
# Exclude non-skill directories under skills/ (bundled skill packs for alt configs)
EXCLUDE_TOP_NAMES=("skills-codex" "skills-codex-claude-review" "skills-codex-gemini-review" "skills-codex.bak")

# ─── Argument parsing ─────────────────────────────────────────────────────────
INSTALL_MODE="global"  # global | project
PROJECT_PATH=""
ARIS_REPO_OVERRIDE=""
ACTION="auto"        # auto | reconcile | uninstall
DRY_RUN=false
QUIET=false
NO_DOC=false
FROM_OLD=false
MIGRATE_COPY=""
CLEAR_STALE_LOCK=false
ADOPT_NAMES=()
REPLACE_LINK_NAMES=()

usage() { sed -n '2,62p' "$0" | sed 's/^# \?//'; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --global)            INSTALL_MODE="global"; shift ;;
        --project)
            INSTALL_MODE="project"
            # Optional inline path
            if [[ $# -ge 2 && -n "$2" && "$2" != --* ]]; then
                PROJECT_PATH="$2"; shift 2
            else
                shift
            fi ;;
        --reconcile)         ACTION="reconcile"; shift ;;
        --uninstall)         ACTION="uninstall"; shift ;;
        --aris-repo)         ARIS_REPO_OVERRIDE="${2:?--aris-repo requires path}"; shift 2 ;;
        --dry-run)           DRY_RUN=true; shift ;;
        --quiet)             QUIET=true; shift ;;
        --no-doc)            NO_DOC=true; shift ;;
        --from-old)          FROM_OLD=true; shift ;;
        --migrate-copy)      MIGRATE_COPY="${2:?--migrate-copy requires keep-user|prefer-upstream}"; shift 2 ;;
        --clear-stale-lock)  CLEAR_STALE_LOCK=true; shift ;;
        --adopt-existing)    ADOPT_NAMES+=("${2:?--adopt-existing requires NAME}"); shift 2 ;;
        --replace-link)      REPLACE_LINK_NAMES+=("${2:?--replace-link requires NAME}"); shift 2 ;;
        -h|--help)           usage; exit 0 ;;
        --*)                 echo "Unknown option: $1" >&2; exit 2 ;;
        *)
            # Legacy positional project path (backward-compat)
            if [[ -z "$PROJECT_PATH" && "$INSTALL_MODE" == "global" ]]; then
                INSTALL_MODE="project"; PROJECT_PATH="$1"; shift
            elif [[ -z "$PROJECT_PATH" ]]; then
                PROJECT_PATH="$1"; shift
            else
                echo "Error: unexpected positional: $1" >&2; exit 2
            fi ;;
    esac
done

if [[ -n "$MIGRATE_COPY" && "$MIGRATE_COPY" != "keep-user" && "$MIGRATE_COPY" != "prefer-upstream" ]]; then
    echo "Error: --migrate-copy must be keep-user or prefer-upstream (got: $MIGRATE_COPY)" >&2; exit 2
fi

# ─── Helpers ──────────────────────────────────────────────────────────────────
log()      { $QUIET && return 0; echo "$@"; }
warn()     { echo "warning: $*" >&2; }
die()      { echo "error: $*" >&2; exit 1; }
prompt()   { $QUIET && return 1; printf "%s " "$1" >&2; read -r REPLY; [[ "$REPLY" =~ ^[Yy]$ ]]; }
abs_path() { ( cd "$1" 2>/dev/null && pwd ) || return 1; }

is_safe_name() { [[ "$1" =~ $SAFE_NAME_REGEX ]]; }

read_link_target() {
    if command -v greadlink >/dev/null 2>&1; then greadlink "$1"
    else readlink "$1"; fi
}

canonicalize() {
    if command -v greadlink >/dev/null 2>&1; then greadlink -f "$1" 2>/dev/null || true
    elif readlink -f "$1" 2>/dev/null; then :
    else
        local d f
        if [[ -d "$1" ]]; then ( cd "$1" && pwd )
        else d="$(dirname "$1")"; f="$(basename "$1")"; ( cd "$d" 2>/dev/null && echo "$(pwd)/$f" )
        fi
    fi
}

is_symlink() { [[ -L "$1" ]]; }

# Resolve install root based on mode
resolve_install_root() {
    case "$INSTALL_MODE" in
        global)
            local claude_home="${CLAUDE_HOME:-$HOME/.claude}"
            echo "$claude_home" ;;
        project)
            local p="${PROJECT_PATH:-$(pwd)}"
            [[ -d "$p" ]] || die "project path does not exist: $p"
            abs_path "$p" ;;
    esac
}

resolve_aris_repo() {
    local p
    if [[ -n "$ARIS_REPO_OVERRIDE" ]]; then
        p="$(abs_path "$ARIS_REPO_OVERRIDE")" || die "--aris-repo path not found: $ARIS_REPO_OVERRIDE"
        [[ -d "$p/skills" ]] || die "--aris-repo has no skills/ subdir: $p"
        echo "$p"; return
    fi
    local script_dir parent
    script_dir="$(cd "$(dirname "$0")" && pwd)"
    parent="$(cd "$script_dir/.." && pwd)"
    if [[ -d "$parent/skills" ]]; then echo "$parent"; return; fi
    if [[ -n "${ARIS_REPO:-}" && -d "$ARIS_REPO/skills" ]]; then abs_path "$ARIS_REPO"; return; fi
    for guess in \
        "$HOME/Music/Auto-claude-code-research-in-sleep" \
        "$HOME/Desktop/Auto-claude-code-research-in-sleep" \
        "$HOME/aris_repo" \
        "$HOME/.aris" ; do
        [[ -d "$guess/skills" ]] && { abs_path "$guess"; return; }
    done
    die "cannot find ARIS repo. Use --aris-repo PATH or set ARIS_REPO env var."
}

build_upstream_inventory() {
    local repo="$1"
    local skills_dir="$repo/skills"
    local name src
    for d in "$skills_dir"/*/; do
        name="$(basename "$d")"
        is_safe_name "$name" || { warn "skipping unsafe upstream name: $name"; continue; }
        for ex in "${EXCLUDE_TOP_NAMES[@]}"; do [[ "$name" == "$ex" ]] && continue 2; done
        local is_support=false
        for s in "${SUPPORT_NAMES[@]}"; do [[ "$name" == "$s" ]] && { is_support=true; break; }; done
        if $is_support; then continue; fi
        if [[ ! -f "$d/SKILL.md" ]]; then continue; fi
        src="$skills_dir/$name"
        if is_symlink "$src"; then
            local resolved; resolved="$(canonicalize "$src")"
            [[ "$resolved" == "$repo"/* ]] || { warn "skipping upstream symlink leading outside repo: $name -> $resolved"; continue; }
        fi
        echo "skill|$name"
    done
    for s in "${SUPPORT_NAMES[@]}"; do
        if [[ -d "$skills_dir/$s" ]]; then echo "support|$s"; fi
    done
}

load_manifest() {
    local path="$1" out="$2"
    : > "$out"
    [[ -f "$path" ]] || return 0
    local ver; ver="$(awk -F'\t' '$1=="version"{print $2}' "$path" | head -1)"
    [[ "$ver" == "$MANIFEST_VERSION" ]] || die "manifest version mismatch (file: $ver, expected: $MANIFEST_VERSION)"
    awk -F'\t' '
        BEGIN { in_body=0 }
        /^kind\tname\tsource_rel\ttarget_rel\tmode$/ { in_body=1; next }
        in_body && NF==5 { print }
    ' "$path" > "$out"
}

manifest_lookup_target() {
    awk -F'\t' -v n="$2" '$2==n {print $4; exit}' "$1"
}
manifest_names() { awk -F'\t' '{print $2}' "$1"; }
manifest_kind_of() {
    awk -F'\t' -v n="$2" '$2==n {print $1; exit}' "$1"
}

# ─── Resolve install root & aris-repo ────────────────────────────────────────
INSTALL_ROOT="$(resolve_install_root)"
mkdir -p "$INSTALL_ROOT"
INSTALL_ROOT="$(abs_path "$INSTALL_ROOT")"

ARIS_REPO="$(resolve_aris_repo)"
SKILLS_DIR_ABS="$ARIS_REPO/skills"

# Determine target skills dir based on mode
if [[ "$INSTALL_MODE" == "global" ]]; then
    # Global: ~/.claude/skills/ (flat, not under .claude/)
    INSTALL_SKILLS_DIR="$INSTALL_ROOT/skills"
    INSTALL_ARIS_DIR="$INSTALL_ROOT/.aris"   # manifest lives at ~/.claude/.aris/
else
    # Project: <project>/.claude/skills/
    INSTALL_SKILLS_DIR="$INSTALL_ROOT/$SKILLS_REL"
    INSTALL_ARIS_DIR="$INSTALL_ROOT/$ARIS_DIR_NAME"
fi

MANIFEST_PATH="$INSTALL_ARIS_DIR/$MANIFEST_NAME"
MANIFEST_PREV="$INSTALL_ARIS_DIR/$MANIFEST_PREV_NAME"
LOCK_DIR="$INSTALL_ARIS_DIR/$LOCK_DIR_NAME"
DOC_FILE="$INSTALL_ROOT/$DOC_FILE_NAME"

# ─── S9: refuse if critical dirs are themselves symlinks ─────────────────────
check_no_symlinked_parents() {
    local p
    for p in "$INSTALL_ARIS_DIR" "$INSTALL_ROOT/.claude" "$INSTALL_SKILLS_DIR"; do
        if is_symlink "$p"; then
            die "S9: $p is a symlink — refusing to install (would mutate symlink target)"
        fi
    done
}

# ─── Lock acquisition ────────────────────────────────────────────────────────
write_lock_metadata() {
    cat > "$LOCK_DIR/owner.json" <<EOF
{"host":"$(hostname)","pid":$$,"started_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","tool":"install_aris.sh","mode":"$INSTALL_MODE"}
EOF
    echo "$$" > "$LOCK_DIR/owner.pid"
    echo "$(hostname)" > "$LOCK_DIR/owner.host"
}

acquire_lock() {
    mkdir -p "$INSTALL_ARIS_DIR"
    if mkdir "$LOCK_DIR" 2>/dev/null; then
        write_lock_metadata
        trap release_lock EXIT INT TERM
        return 0
    fi
    if $CLEAR_STALE_LOCK; then
        local owner=""
        [[ -f "$LOCK_DIR/owner.json" ]] && owner="$(cat "$LOCK_DIR/owner.json")"
        warn "removing stale lock: $LOCK_DIR (was: $owner)"
        rm -rf "$LOCK_DIR"
        mkdir "$LOCK_DIR" || die "still cannot acquire lock after stale clear"
        write_lock_metadata
        trap release_lock EXIT INT TERM
        return 0
    fi
    local owner=""
    [[ -f "$LOCK_DIR/owner.json" ]] && owner="$(cat "$LOCK_DIR/owner.json")"
    die "another install_aris.sh is running for this install root (lock: $LOCK_DIR)
       owner: $owner
       if you are sure no install is in progress, rerun with --clear-stale-lock"
}

release_lock() {
    [[ -d "$LOCK_DIR" ]] || return 0
    if [[ -f "$LOCK_DIR/owner.pid" ]]; then
        local pid; pid="$(cat "$LOCK_DIR/owner.pid" 2>/dev/null || echo "")"
        local host; host="$(cat "$LOCK_DIR/owner.host" 2>/dev/null || echo "")"
        if [[ "$pid" == "$$" && "$host" == "$(hostname)" ]]; then
            rm -rf "$LOCK_DIR"
        fi
    fi
}

# ─── Legacy detection ────────────────────────────────────────────────────────
LEGACY_NESTED="$INSTALL_SKILLS_DIR/aris"

detect_legacy() {
    if [[ ! -e "$LEGACY_NESTED" && ! -L "$LEGACY_NESTED" ]]; then echo "none"; return; fi
    if is_symlink "$LEGACY_NESTED"; then
        local tgt; tgt="$(read_link_target "$LEGACY_NESTED")"
        if [[ "$tgt" == "$SKILLS_DIR_ABS" || "$tgt" == "$SKILLS_DIR_ABS/" ]]; then
            echo "symlink_to_repo"
        else
            echo "symlink_to_other"
        fi
    elif [[ -d "$LEGACY_NESTED" ]]; then
        echo "real_dir"
    else
        echo "real_file"
    fi
}

migrate_legacy() {
    local kind; kind="$(detect_legacy)"
    case "$kind" in
        none) return 0 ;;
        symlink_to_repo)
            log "→ migrating legacy nested symlink: removing $LEGACY_NESTED"
            $DRY_RUN || rm -f "$LEGACY_NESTED"
            return 0 ;;
        symlink_to_other)
            die "S2: legacy $LEGACY_NESTED is a symlink to OUTSIDE the repo — refusing to touch.
       investigate manually before re-running." ;;
        real_file)
            die "$LEGACY_NESTED is a regular file (unexpected). Move/delete it manually." ;;
        real_dir)
            if [[ -z "$MIGRATE_COPY" ]]; then
                die "legacy nested COPY install detected at $LEGACY_NESTED.
       --migrate-copy keep-user | prefer-upstream"
            fi
            return 0 ;;
    esac
}

archive_legacy_copy() {
    local ts; ts="$(date -u +%Y%m%dT%H%M%SZ)"
    local archive="$INSTALL_ARIS_DIR/legacy-copy-backup-$ts"
    log "→ archiving legacy nested copy to: $archive"
    $DRY_RUN || mv "$LEGACY_NESTED" "$archive"
}

# ─── Plan computation ────────────────────────────────────────────────────────
compute_plan() {
    local upstream_file="$1" manifest_data="$2" out="$3"
    : > "$out"
    local target_path src expected_target current_target line kind name
    while IFS='|' read -r kind name; do
        [[ -z "$name" ]] && continue
        target_path="$INSTALL_SKILLS_DIR/$name"
        expected_target="$SKILLS_DIR_ABS/$name"
        if [[ -L "$target_path" ]]; then
            current_target="$(read_link_target "$target_path")"
            if [[ "$current_target" != /* ]]; then
                current_target="$(canonicalize "$INSTALL_SKILLS_DIR/$current_target")"
            fi
            local in_manifest=false
            if [[ -n "$(manifest_lookup_target "$manifest_data" "$name")" ]]; then in_manifest=true; fi
            if [[ "$current_target" == "$expected_target" ]]; then
                if $in_manifest; then echo "REUSE|$kind|$name|" >> "$out"
                else echo "ADOPT|$kind|$name|" >> "$out"
                fi
            else
                if $in_manifest; then
                    echo "UPDATE_TARGET|$kind|$name|$current_target" >> "$out"
                else
                    echo "CONFLICT|$kind|$name|symlink_to:$current_target" >> "$out"
                fi
            fi
        elif [[ -e "$target_path" ]]; then
            echo "CONFLICT|$kind|$name|real_path" >> "$out"
        else
            echo "CREATE|$kind|$name|" >> "$out"
        fi
    done < "$upstream_file"
    while IFS=$'\t' read -r mkind mname msrc mtarget mmode; do
        [[ -z "$mname" ]] && continue
        if grep -q "^[^|]*|$mname$" "$upstream_file"; then continue; fi
        echo "REMOVE|$mkind|$mname|" >> "$out"
    done < "$manifest_data"
}

print_plan() {
    local plan="$1"
    local n_create n_update n_reuse n_remove n_adopt n_conflict
    n_create=$(grep -c '^CREATE|' "$plan" || true)
    n_update=$(grep -c '^UPDATE_TARGET|' "$plan" || true)
    n_reuse=$(grep -c '^REUSE|' "$plan" || true)
    n_remove=$(grep -c '^REMOVE|' "$plan" || true)
    n_adopt=$(grep -c '^ADOPT|' "$plan" || true)
    n_conflict=$(grep -c '^CONFLICT|' "$plan" || true)
    log ""
    log "Plan summary:"
    log "  CREATE:        $n_create  (new flat symlinks to add)"
    log "  ADOPT:         $n_adopt   (orphan symlinks already pointing to correct target)"
    log "  UPDATE_TARGET: $n_update  (managed symlinks with stale target)"
    log "  REUSE:         $n_reuse   (already correct, no-op)"
    log "  REMOVE:        $n_remove  (in old manifest, no longer upstream)"
    log "  CONFLICT:      $n_conflict  (must be resolved before apply)"
    if (( n_conflict > 0 )); then
        log ""
        log "Conflicts (need user action):"
        grep '^CONFLICT|' "$plan" | while IFS='|' read -r _ kind name extra; do
            log "  - $name ($kind): $extra"
        done
    fi
}

# ─── Apply ───────────────────────────────────────────────────────────────────
write_manifest_tmp() {
    local plan="$1" out="$2"
    {
        printf "version\t%s\n" "$MANIFEST_VERSION"
        printf "repo_root\t%s\n" "$ARIS_REPO"
        printf "install_mode\t%s\n" "$INSTALL_MODE"
        printf "install_root\t%s\n" "$INSTALL_ROOT"
        printf "generated\t%s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        printf "kind\tname\tsource_rel\ttarget_rel\tmode\n"
        awk -F'|' '$1=="REUSE"||$1=="ADOPT"||$1=="CREATE"||$1=="UPDATE_TARGET"{print $0}' "$plan" \
        | while IFS='|' read -r action kind name _; do
            local tgt_rel
            if [[ "$INSTALL_MODE" == "global" ]]; then
                tgt_rel="skills/$name"
            else
                tgt_rel="$SKILLS_REL/$name"
            fi
            printf "%s\t%s\tskills/%s\t%s\tsymlink\n" "$kind" "$name" "$name" "$tgt_rel"
        done
    } > "$out"
}

apply_plan() {
    local plan="$1" manifest_tmp="$2"
    mkdir -p "$INSTALL_SKILLS_DIR"
    local action kind name extra target_path expected_target
    while IFS='|' read -r action kind name extra; do
        [[ -z "$name" ]] && continue
        target_path="$INSTALL_SKILLS_DIR/$name"
        expected_target="$SKILLS_DIR_ABS/$name"
        case "$action" in
            REUSE|ADOPT) : ;;
            CREATE)
                if [[ -e "$target_path" || -L "$target_path" ]]; then
                    die "S4 violation: $target_path appeared between plan and apply"
                fi
                if $DRY_RUN; then log "  (dry-run) ln -s $expected_target $target_path"
                else ln -s "$expected_target" "$target_path"; log "  + $name"
                fi ;;
            UPDATE_TARGET)
                local plan_saw_target; plan_saw_target="$(read_link_target "$target_path" 2>/dev/null || echo "")"
                [[ "$plan_saw_target" != /* && -n "$plan_saw_target" ]] && plan_saw_target="$(canonicalize "$(dirname "$target_path")/$plan_saw_target")"
                if [[ "$plan_saw_target" != "$extra" ]]; then
                    warn "S11: $target_path target changed since plan — skipping"
                    continue
                fi
                if [[ "$plan_saw_target" != "$ARIS_REPO"/* ]]; then
                    warn "S2: refusing to replace symlink pointing outside aris-repo: $target_path -> $plan_saw_target"
                    continue
                fi
                if $DRY_RUN; then log "  (dry-run) update target: $target_path -> $expected_target"
                else
                    rm -f "$target_path"
                    ln -s "$expected_target" "$target_path"
                    log "  ↻ $name"
                fi ;;
            REMOVE)
                is_symlink "$target_path" || { warn "S1: $target_path is not a symlink, refusing to remove"; continue; }
                local cur; cur="$(read_link_target "$target_path")"
                [[ "$cur" != /* ]] && cur="$(canonicalize "$(dirname "$target_path")/$cur")"
                [[ "$cur" == "$ARIS_REPO"/* ]] || { warn "S2: $target_path target $cur outside aris-repo, refusing"; continue; }
                if $DRY_RUN; then log "  (dry-run) rm $target_path"
                else rm -f "$target_path"; log "  - $name"
                fi ;;
            CONFLICT) die "BUG: CONFLICT $name reached apply phase" ;;
        esac
    done < "$plan"
}

commit_manifest() {
    local manifest_tmp="$1"
    if $DRY_RUN; then log "  (dry-run) would commit manifest"; return; fi
    if [[ -f "$MANIFEST_PATH" ]]; then
        cp -p "$MANIFEST_PATH" "$MANIFEST_PREV.tmp"
        mv -f "$MANIFEST_PREV.tmp" "$MANIFEST_PREV"
    fi
    mv -f "$manifest_tmp" "$MANIFEST_PATH"
}

# ─── CLAUDE.md update (project-local mode only) ──────────────────────────────
update_claude_doc() {
    local installed_names_file="$1"
    # Only relevant in project-local mode
    [[ "$INSTALL_MODE" == "project" ]] || return 0
    [[ -f "$DOC_FILE" ]] || { log "  (skip CLAUDE.md: file not present)"; return 0; }
    if $NO_DOC; then return 0; fi

    local original new_block tmp
    original="$(cat "$DOC_FILE")"
    local count; count="$(wc -l < "$installed_names_file" | tr -d ' ')"
    new_block="$BLOCK_BEGIN
## ARIS Skill Scope
ARIS skills installed in this project: $count entries.
Manifest: \`$ARIS_DIR_NAME/$MANIFEST_NAME\` (lists every skill ARIS installed and its upstream target).
For ARIS workflows, prefer the project-local skills under \`$SKILLS_REL/\` over global skills.
Do not modify or delete files inside any skill that is a symlink (symlinks point into \`$ARIS_REPO\`).
Update with: \`bash $ARIS_REPO/tools/install_aris.sh --project $INSTALL_ROOT\`  (re-runnable; reconciles new/removed skills).
$BLOCK_END"

    local new_content
    if printf '%s' "$original" | grep -qF "$BLOCK_BEGIN"; then
        new_content="$(python3 - "$DOC_FILE" "$BLOCK_BEGIN" "$BLOCK_END" "$new_block" <<'PYEOF'
import re, sys, pathlib
path, begin, end, body = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
text = pathlib.Path(path).read_text()
pattern = re.compile(re.escape(begin) + r".*?" + re.escape(end), re.DOTALL)
matches = pattern.findall(text)
if len(matches) > 1:
    sys.stderr.write("ARIS:WARN multiple ARIS blocks found in CLAUDE.md; skipping update\n")
    sys.stdout.write(text)
else:
    sys.stdout.write(pattern.sub(body, text))
PYEOF
        )" || { warn "CLAUDE.md update failed (best-effort, continuing)"; return 0; }
    else
        new_content="$original"
        [[ -n "$original" ]] && new_content="${new_content}"$'\n'
        new_content="${new_content}${new_block}"$'\n'
    fi

    if $DRY_RUN; then log "  (dry-run) would update CLAUDE.md ARIS block"; return 0; fi
    tmp="$DOC_FILE.aris-tmp.$$"
    printf '%s' "$new_content" > "$tmp"
    local current; current="$(cat "$DOC_FILE")"
    if [[ "$current" != "$original" ]]; then
        rm -f "$tmp"
        warn "CLAUDE.md changed during install — skipping doc update (rerun to retry)"
        return 0
    fi
    mv -f "$tmp" "$DOC_FILE"
    log "  ✓ updated CLAUDE.md (ARIS managed block)"
}

# ─── Uninstall ───────────────────────────────────────────────────────────────
do_uninstall() {
    [[ -f "$MANIFEST_PATH" ]] || die "no manifest at $MANIFEST_PATH; nothing to uninstall"
    local manifest_data; manifest_data="$(mktemp -t aris-manifest.XXXXXX)"
    load_manifest "$MANIFEST_PATH" "$manifest_data"
    log ""
    log "Uninstall plan ($INSTALL_MODE mode, root: $INSTALL_ROOT):"
    while IFS=$'\t' read -r kind name src target mode; do
        [[ -z "$name" ]] && continue
        log "  - $name ($kind)"
    done < "$manifest_data"
    if ! $DRY_RUN && ! $QUIET; then
        prompt "Proceed?" || { log "aborted"; exit 0; }
    fi
    while IFS=$'\t' read -r kind name src target mode; do
        [[ -z "$name" ]] && continue
        local target_path="$INSTALL_ROOT/$target"
        local expected="$SKILLS_DIR_ABS/$name"
        is_symlink "$target_path" || { warn "S1: $target_path not a symlink, skipping"; continue; }
        local cur; cur="$(read_link_target "$target_path")"
        [[ "$cur" != /* ]] && cur="$(canonicalize "$(dirname "$target_path")/$cur")"
        if [[ "$cur" != "$expected" ]]; then
            warn "S8: $target_path target $cur != expected $expected, skipping"
            continue
        fi
        if $DRY_RUN; then log "  (dry-run) rm $target_path"
        else rm -f "$target_path"; log "  - removed $name"
        fi
    done < "$manifest_data"
    rm -f "$manifest_data"
    if ! $DRY_RUN; then
        [[ -f "$MANIFEST_PATH" ]] && mv -f "$MANIFEST_PATH" "$MANIFEST_PREV"
        log "  ✓ uninstalled (manifest preserved as $MANIFEST_PREV for forensics)"
    fi
}

# ─── Main ────────────────────────────────────────────────────────────────────
log ""
log "ARIS Install"
log "  Mode:         $INSTALL_MODE"
log "  Install root: $INSTALL_ROOT"
log "  Skills dir:   $INSTALL_SKILLS_DIR"
log "  ARIS repo:    $ARIS_REPO"
log "  Action:       $ACTION$($DRY_RUN && echo ' (dry-run)')"
log ""

check_no_symlinked_parents
acquire_lock

if [[ "$ACTION" == "uninstall" ]]; then
    do_uninstall
    exit 0
fi

LEGACY_KIND="$(detect_legacy)"
if [[ "$LEGACY_KIND" != "none" ]]; then
    if ! $FROM_OLD; then
        log "Legacy nested install detected: $LEGACY_NESTED ($LEGACY_KIND)"
        log "→ to migrate, rerun with --from-old"
        log "  for COPY-style legacy installs, also pass --migrate-copy keep-user|prefer-upstream"
        exit 1
    fi
    migrate_legacy
fi

if [[ "$ACTION" == "reconcile" && ! -f "$MANIFEST_PATH" ]]; then
    die "--reconcile requires existing manifest; none found at $MANIFEST_PATH"
fi

UPSTREAM_FILE="$(mktemp -t aris-upstream.XXXXXX)"
build_upstream_inventory "$ARIS_REPO" > "$UPSTREAM_FILE"
[[ -s "$UPSTREAM_FILE" ]] || die "upstream inventory empty (broken aris-repo?)"

MANIFEST_DATA="$(mktemp -t aris-manifest.XXXXXX)"
load_manifest "$MANIFEST_PATH" "$MANIFEST_DATA"

PLAN_FILE="$(mktemp -t aris-plan.XXXXXX)"
compute_plan "$UPSTREAM_FILE" "$MANIFEST_DATA" "$PLAN_FILE"
print_plan "$PLAN_FILE"

N_CONFLICT=$(grep -c '^CONFLICT|' "$PLAN_FILE" || true)
if (( N_CONFLICT > 0 )); then
    if [[ ${#REPLACE_LINK_NAMES[@]} -gt 0 ]]; then
        for n in "${REPLACE_LINK_NAMES[@]}"; do
            sed -i.bak "s|^CONFLICT|$n|UPDATE_TARGET|$n|" "$PLAN_FILE" 2>/dev/null || true
            rm -f "$PLAN_FILE.bak"
        done
        N_CONFLICT=$(grep -c '^CONFLICT|' "$PLAN_FILE" || true)
    fi
    if (( N_CONFLICT > 0 )); then
        log ""
        log "Aborting due to $N_CONFLICT unresolved conflicts."
        log "Resolve options:"
        log "  - back up & remove the conflicting path manually, then rerun"
        log "  - if it's a foreign symlink to be replaced: --replace-link NAME"
        exit 1
    fi
fi

if $DRY_RUN; then
    log ""
    log "(dry-run) no changes made"
    exit 0
fi

N_CHANGES=$(awk -F'|' '$1=="CREATE"||$1=="UPDATE_TARGET"||$1=="REMOVE"' "$PLAN_FILE" | wc -l | tr -d ' ')
if (( N_CHANGES > 0 )) && ! $QUIET; then
    prompt "Apply these $N_CHANGES changes?" || { log "aborted"; exit 0; }
fi

MANIFEST_TMP="$MANIFEST_PATH.tmp.$$"
mkdir -p "$INSTALL_ARIS_DIR"
write_manifest_tmp "$PLAN_FILE" "$MANIFEST_TMP"
log ""
log "Applying:"
apply_plan "$PLAN_FILE" "$MANIFEST_TMP"
commit_manifest "$MANIFEST_TMP"

if [[ "$LEGACY_KIND" == "real_dir" && "$MIGRATE_COPY" == "prefer-upstream" ]]; then
    archive_legacy_copy
fi

INSTALLED_NAMES="$(mktemp -t aris-names.XXXXXX)"
awk -F'|' '$1=="REUSE"||$1=="ADOPT"||$1=="CREATE"||$1=="UPDATE_TARGET"{print $3}' "$PLAN_FILE" > "$INSTALLED_NAMES"
update_claude_doc "$INSTALLED_NAMES"
rm -f "$INSTALLED_NAMES"

if ! $DRY_RUN; then
    BAD=0
    while IFS=$'\t' read -r v_kind v_name v_src v_target v_mode; do
        [[ -z "$v_name" ]] && continue
        VTARGET="$INSTALL_ROOT/$v_target"
        if ! is_symlink "$VTARGET"; then warn "verify: $VTARGET missing"; BAD=$((BAD+1)); fi
    done < <(awk -F'\t' '
        BEGIN { in_body=0 }
        /^kind\tname\tsource_rel\ttarget_rel\tmode$/ { in_body=1; next }
        in_body && NF==5 { print }
    ' "$MANIFEST_PATH")
    (( BAD == 0 )) && log "" && log "✓ Install complete. $N_CHANGES changes applied."
fi

rm -f "$UPSTREAM_FILE" "$MANIFEST_DATA" "$PLAN_FILE"
