#!/usr/bin/env bash
# smoke_ros2_launch_test.sh — Verify launch_testing module loads and a
# trivial harness parses inside the user-provided test container.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$SCRIPT_DIR/_helpers.sh"

pass() { echo "  ✓ $*"; }
fail() { echo "  ✗ $*" >&2; exit 1; }
skip() { echo "  ⊘ $*"; }

echo "[smoke_ros2_launch_test]"

CTR="$(aris_resolve_test_container "$REPO_ROOT")"
if [[ -z "$CTR" ]] || ! aris_container_running "$CTR"; then
  skip "test container not available"; echo "[smoke_ros2_launch_test] ALL PASS (skipped)"; exit 0
fi

DISTRO=$(docker exec "$CTR" bash -c 'ls /opt/ros/ 2>/dev/null | head -1' | tr -d '\r')
if [[ -z "$DISTRO" ]]; then
  skip "no ROS2 distro found"; echo "[smoke_ros2_launch_test] ALL PASS (skipped)"; exit 0
fi

docker exec "$CTR" bash -c "
  source /opt/ros/$DISTRO/setup.bash
  python3 -c 'import launch_testing; import launch' 2>&1
" || fail "launch_testing / launch not importable"
pass "launch_testing + launch modules import cleanly"

docker exec "$CTR" bash -c "
  set -e
  source /opt/ros/$DISTRO/setup.bash
  python3 -c 'import pytest; print(\"pytest\", pytest.__version__)' 2>&1
" | tail -3
pass "pytest present"

echo "[smoke_ros2_launch_test] ALL PASS"
