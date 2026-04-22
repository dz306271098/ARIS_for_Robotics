#!/usr/bin/env bash
# smoke_verify_wiki_coverage.sh — Verify wiki coverage diagnostic runs clean.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass() { echo "  ✓ $*"; }
fail() { echo "  ✗ $*" >&2; exit 1; }

echo "[smoke_verify_wiki_coverage] TMP=$TMP"

# 1. Setup: init a fresh empty wiki
python3 tools/research_wiki.py init "$TMP/research-wiki" >/dev/null
pass "empty wiki initialized"

# 2. Run coverage diagnostic (non-blocking, diagnostic only)
set +e
bash tools/verify_wiki_coverage.sh "$TMP/research-wiki" --json-out "$TMP/report.json" >/dev/null 2>&1
EXIT=$?
set -e

# Diagnostic is documented as "exit 0 regardless of coverage outcome"
[[ "$EXIT" == "0" ]] || fail "verify_wiki_coverage should exit 0 (diagnostic), got $EXIT"
pass "verify_wiki_coverage exits 0 (diagnostic)"

[[ -f "$TMP/report.json" ]] || fail "report JSON not created"
pass "report JSON written"

# 3. Valid JSON
python3 -c "import json; json.load(open('$TMP/report.json'))" || fail "report JSON malformed"
pass "report JSON parses as valid JSON"

echo "[smoke_verify_wiki_coverage] ALL PASS"
