#!/usr/bin/env bash
# smoke_uninstall_aris.sh — Verify uninstall wrapper's --archive-copy helper.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass() { echo "  ✓ $*"; }
fail() { echo "  ✗ $*" >&2; exit 1; }

echo "[smoke_uninstall_aris] TMP=$TMP"

# 1. Simulate legacy cp -r install: create real directories (not symlinks)
mkdir -p "$TMP/.claude/skills/fake-skill-1" "$TMP/.claude/skills/fake-skill-2"
echo "content" > "$TMP/.claude/skills/fake-skill-1/SKILL.md"
echo "content" > "$TMP/.claude/skills/fake-skill-2/SKILL.md"
pass "setup: 2 real directories under $TMP/.claude/skills/"

# 2. --help works
bash tools/uninstall_aris.sh --help >/dev/null || fail "--help failed"
pass "--help works"

# 3. --archive-copy (auto-confirm with yes)
echo y | bash tools/uninstall_aris.sh --project "$TMP" --archive-copy >/dev/null 2>&1 || fail "archive-copy failed"

# 4. Verify archive dir exists and real dirs are moved
ARCHIVE=$(ls -d "$TMP/.claude/skills.aris-backup-"* 2>/dev/null | head -1)
[[ -n "$ARCHIVE" ]] || fail "archive dir not created"
[[ -d "$ARCHIVE/fake-skill-1" ]] || fail "fake-skill-1 not archived"
[[ -d "$ARCHIVE/fake-skill-2" ]] || fail "fake-skill-2 not archived"
[[ ! -d "$TMP/.claude/skills/fake-skill-1" ]] || fail "fake-skill-1 not removed from original location"
pass "--archive-copy moved 2 real dirs to $ARCHIVE"

# 5. uninstall with no manifest errors gracefully (exit 1, clear message)
rm -rf "$TMP/.aris"
mkdir -p "$TMP/.claude/skills"
OUT=$(bash tools/uninstall_aris.sh --project "$TMP" --dry-run 2>&1 || true)
echo "$OUT" | grep -q "no ARIS manifest" || fail "expected 'no ARIS manifest' message"
pass "uninstall without manifest gives clear error"

echo "[smoke_uninstall_aris] ALL PASS"
