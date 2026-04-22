#!/usr/bin/env bash
# run_all.sh — ARIS smoke test umbrella.
# Runs all v2.1 smoke tests; exits non-zero if any fail.

set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

TESTS=(
    "smoke_shared_refs.sh"
    "smoke_skill_frontmatter.sh"
    "smoke_research_wiki.sh"
    "smoke_install_aris.sh"
    "smoke_uninstall_aris.sh"
    "smoke_verify_paper_audits.sh"
    "smoke_verify_wiki_coverage.sh"
)

PASS=0
FAIL=0
FAILED_NAMES=()

echo "════════════════════════════════════════════════════"
echo "  ARIS v2.1 Smoke Test Suite"
echo "════════════════════════════════════════════════════"

for t in "${TESTS[@]}"; do
    echo ""
    echo "▶ Running $t"
    if bash "$SCRIPT_DIR/$t"; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        FAILED_NAMES+=("$t")
    fi
done

echo ""
echo "════════════════════════════════════════════════════"
echo "  Summary: $PASS passed, $FAIL failed (of ${#TESTS[@]})"
if (( FAIL > 0 )); then
    echo "  FAILED:"
    for n in "${FAILED_NAMES[@]}"; do echo "    - $n"; done
fi
echo "════════════════════════════════════════════════════"

(( FAIL == 0 ))
