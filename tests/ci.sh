#!/usr/bin/env bash
# tests/ci.sh — CI entry point. Detects environment and runs the appropriate
# combination of host + container test suites.
#
# Return codes:
#   0  host suite PASS; container suite PASS or gracefully skipped
#   1  any test failure

set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "════════════════════════════════════════════════════"
echo "  ARIS CI Entry"
echo "════════════════════════════════════════════════════"

# Host suite always runs
echo ""
echo "[ci] Host suite"
if ! bash "$SCRIPT_DIR/run_all.sh"; then
    echo "[ci] Host suite FAILED — exiting"
    exit 1
fi

# Container suite — run if a test container is configured + running
source "$SCRIPT_DIR/container/_helpers.sh"
CTR="$(aris_resolve_test_container "$REPO_ROOT")"
if [[ -n "$CTR" ]] && aris_container_running "$CTR"; then
    echo ""
    echo "[ci] Container suite (target: $CTR)"
    if ! bash "$SCRIPT_DIR/container/run_all.sh"; then
        echo "[ci] Container suite FAILED — exiting"
        exit 1
    fi
else
    echo ""
    echo "[ci] Container suite SKIPPED (no test container configured or running)"
    echo "     set \$ARIS_TEST_CONTAINER to enable"
fi

echo ""
echo "[ci] All suites PASS"
