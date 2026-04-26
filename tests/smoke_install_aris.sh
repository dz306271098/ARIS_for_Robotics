#!/usr/bin/env bash
# smoke_install_aris.sh — Project-mode install / reconcile / uninstall lifecycle.
# Uses a temp project dir so no user state is touched.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass() { echo "  ✓ $*"; }
fail() { echo "  ✗ $*" >&2; exit 1; }

echo "[smoke_install_aris] TMP=$TMP"

# 1. Fresh install (project-mode, quiet)
bash tools/install_aris.sh --project "$TMP" --quiet >/dev/null 2>&1 || fail "install failed"
[[ -d "$TMP/.claude/skills" ]] || fail "skills dir not created"
[[ -f "$TMP/.aris/installed-skills.txt" ]] || fail "manifest not created"

# Verify symlinks point into aris-repo
N_LINKS=$(find "$TMP/.claude/skills" -maxdepth 1 -type l | wc -l | tr -d ' ')
(( N_LINKS >= 66 )) || fail "expected ≥66 symlinks (v2.2: 52 baseline + 14 domain skills), got $N_LINKS"
pass "install created $N_LINKS symlinks"

# Check manifest structure
grep -q "^version	1" "$TMP/.aris/installed-skills.txt" || fail "manifest missing version"
grep -q "^kind	name	source_rel	target_rel	mode" "$TMP/.aris/installed-skills.txt" || fail "manifest missing header"
pass "manifest schema valid"

# Check citation-audit is installed (v2.1)
[[ -L "$TMP/.claude/skills/citation-audit" ]] || fail "citation-audit symlink missing"
TGT=$(readlink "$TMP/.claude/skills/citation-audit")
[[ "$TGT" == */skills/citation-audit ]] || fail "citation-audit points to wrong target: $TGT"
pass "citation-audit symlink points correctly"

# Check all 14 v2.2 domain skills are installed by name (catches regressions
# where the symlink count happens to be ≥66 but the wrong skills were installed).
V22_SKILLS=(
    cpp-build cpp-sanitize cpp-bench cpp-profile complexity-claim-audit
    ros2-build ros2-launch-test ros2-bag-replay ros2-realtime-audit
    cuda-build cuda-sanitize cuda-profile cuda-correctness-audit tensorrt-engine-audit
)
for skill in "${V22_SKILLS[@]}"; do
    [[ -L "$TMP/.claude/skills/$skill" ]] || fail "v2.2 skill missing symlink: $skill"
    grep -q "^skill	$skill	" "$TMP/.aris/installed-skills.txt" || fail "v2.2 skill missing from manifest: $skill"
done
pass "all 14 v2.2 domain skills (cpp/ros2/cuda/tensorrt) installed + manifested"

# Check shared-references support entry is installed
[[ -L "$TMP/.claude/skills/shared-references" ]] || fail "shared-references support entry missing"
grep -q "^support	shared-references	" "$TMP/.aris/installed-skills.txt" || fail "shared-references not in manifest as support entry"
pass "shared-references support entry installed"

# 2. Re-run → should be idempotent (all REUSE, 0 changes)
OUT=$(bash tools/install_aris.sh --project "$TMP" --quiet 2>&1 || true)
# Should not create new symlinks
N_LINKS2=$(find "$TMP/.claude/skills" -maxdepth 1 -type l | wc -l | tr -d ' ')
[[ "$N_LINKS" == "$N_LINKS2" ]] || fail "re-run changed link count: $N_LINKS → $N_LINKS2"
pass "re-run is idempotent"

# 3. Reconcile explicitly
bash tools/install_aris.sh --project "$TMP" --reconcile --quiet >/dev/null 2>&1 || fail "reconcile failed"
pass "--reconcile works with existing manifest"

# 3.5. Simulate a v2.1-era manifest (without the 14 v2.2 skills) and verify
# that --reconcile correctly picks them up. This is the upgrade path real
# users hit after pulling a v2.2 ARIS update on top of a v2.1 install.
for s in "${V22_SKILLS[@]}"; do
    rm -f "$TMP/.claude/skills/$s"
    # Strip from manifest in-place (use BSD-portable -i.bak then delete the .bak)
    sed -i.bak "/^skill	$s	/d" "$TMP/.aris/installed-skills.txt"
done
rm -f "$TMP/.aris/installed-skills.txt.bak"
# Confirm we genuinely removed them so the subtest measures the real upgrade
N_LINKS_PRE=$(find "$TMP/.claude/skills" -maxdepth 1 -type l | wc -l | tr -d ' ')
(( N_LINKS_PRE < N_LINKS )) || fail "v2.1-simulation step did not reduce link count: $N_LINKS_PRE vs $N_LINKS"

bash tools/install_aris.sh --project "$TMP" --reconcile --quiet >/dev/null 2>&1 || fail "v2.1→v2.2 reconcile failed"
for s in "${V22_SKILLS[@]}"; do
    [[ -L "$TMP/.claude/skills/$s" ]] || fail "post v2.1→v2.2 reconcile: $s symlink missing"
    grep -q "^skill	$s	" "$TMP/.aris/installed-skills.txt" || fail "post v2.1→v2.2 reconcile: $s not in manifest"
done
N_LINKS_POST=$(find "$TMP/.claude/skills" -maxdepth 1 -type l | wc -l | tr -d ' ')
(( N_LINKS_POST >= N_LINKS )) || fail "post v2.1→v2.2 reconcile: link count regressed ($N_LINKS_POST vs baseline $N_LINKS)"
pass "v2.1→v2.2 reconcile re-adds all 14 v2.2 skills"

# 4. Uninstall
bash tools/install_aris.sh --project "$TMP" --uninstall --quiet >/dev/null 2>&1 || fail "uninstall failed"
N_LINKS3=$(find "$TMP/.claude/skills" -maxdepth 1 -type l 2>/dev/null | wc -l | tr -d ' ')
[[ "$N_LINKS3" == "0" ]] || fail "uninstall left $N_LINKS3 symlinks"
[[ ! -f "$TMP/.aris/installed-skills.txt" ]] || fail "manifest not deleted on uninstall"
[[ -f "$TMP/.aris/installed-skills.txt.prev" ]] || fail "prev manifest not preserved"
pass "uninstall removed all symlinks, retained .prev for forensics"

# 5. Dry-run after full uninstall should propose CREATE for all
DRY_OUT=$(bash tools/install_aris.sh --project "$TMP" --dry-run 2>&1)
echo "$DRY_OUT" | grep -q "CREATE:" || fail "dry-run summary missing CREATE"
pass "--dry-run after uninstall proposes CREATE for all"

echo "[smoke_install_aris] ALL PASS"
