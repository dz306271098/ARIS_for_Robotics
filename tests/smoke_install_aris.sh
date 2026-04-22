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
(( N_LINKS >= 50 )) || fail "expected ≥50 symlinks, got $N_LINKS"
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

# 2. Re-run → should be idempotent (all REUSE, 0 changes)
OUT=$(bash tools/install_aris.sh --project "$TMP" --quiet 2>&1 || true)
# Should not create new symlinks
N_LINKS2=$(find "$TMP/.claude/skills" -maxdepth 1 -type l | wc -l | tr -d ' ')
[[ "$N_LINKS" == "$N_LINKS2" ]] || fail "re-run changed link count: $N_LINKS → $N_LINKS2"
pass "re-run is idempotent"

# 3. Reconcile explicitly
bash tools/install_aris.sh --project "$TMP" --reconcile --quiet >/dev/null 2>&1 || fail "reconcile failed"
pass "--reconcile works with existing manifest"

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
