#!/usr/bin/env bash
# tests/container/run_all.sh — ARIS v2.2 container test suite umbrella.
#
# These tests dispatch into a user-provided test container (the user sets
# $ARIS_TEST_CONTAINER or declares a name in .aris/container.yaml).
# ARIS does NOT ship a container — the tests exist so developers / CI users
# can validate that ARIS's C++/ROS2/CUDA skills run against a live toolchain.
# Tests skip gracefully if no container is configured or the container is
# not running; they never block the host suite.

set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$SCRIPT_DIR/_helpers.sh"

TESTS=(
    "smoke_cuda_build.sh"
    "smoke_cuda_sanitize.sh"
    "smoke_cuda_profile.sh"
    "smoke_ros2_build.sh"
    "smoke_ros2_launch_test.sh"
    "smoke_tensorrt_presence.sh"
)

PASS=0
FAIL=0
FAILED_NAMES=()

CTR="$(aris_resolve_test_container "$REPO_ROOT")"

echo "════════════════════════════════════════════════════"
echo "  ARIS v2.2 Container Test Suite (target: ${CTR:-<none>})"
echo "════════════════════════════════════════════════════"

if [[ -z "$CTR" ]]; then
    echo "  ⊘ no test container configured"
    echo "     set \$ARIS_TEST_CONTAINER=<docker container name> to enable"
    echo "════════════════════════════════════════════════════"
    exit 0
fi
if ! aris_container_running "$CTR"; then
    echo "  ⊘ test container '$CTR' not running — container suite skipped"
    echo "════════════════════════════════════════════════════"
    exit 0
fi

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
echo "  Container Summary: $PASS passed, $FAIL failed (of ${#TESTS[@]})"
if (( FAIL > 0 )); then
    echo "  FAILED:"
    for n in "${FAILED_NAMES[@]}"; do echo "    - $n"; done
fi
echo "════════════════════════════════════════════════════"

(( FAIL == 0 ))
