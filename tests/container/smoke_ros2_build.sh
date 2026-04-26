#!/usr/bin/env bash
# smoke_ros2_build.sh — Build a minimal ROS2 package via colcon inside the
# user-provided test container. Verifies a ROS2 distro toolchain is usable.
# Distro is auto-detected (first /opt/ros/<distro>/ directory found).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$SCRIPT_DIR/_helpers.sh"

pass() { echo "  ✓ $*"; }
fail() { echo "  ✗ $*" >&2; exit 1; }
skip() { echo "  ⊘ $*"; }

echo "[smoke_ros2_build]"

CTR="$(aris_resolve_test_container "$REPO_ROOT")"
if [[ -z "$CTR" ]] || ! aris_container_running "$CTR"; then
  skip "test container not available"; echo "[smoke_ros2_build] ALL PASS (skipped)"; exit 0
fi

DISTRO=$(docker exec "$CTR" bash -c 'ls /opt/ros/ 2>/dev/null | head -1' | tr -d '\r')
if [[ -z "$DISTRO" ]]; then
  skip "no ROS2 distro found under /opt/ros/ inside $CTR"
  echo "[smoke_ros2_build] ALL PASS (skipped)"; exit 0
fi
pass "ROS2 distro: $DISTRO"

docker exec "$CTR" which colcon >/dev/null 2>&1 || fail "colcon not in PATH"
pass "colcon available"

docker exec "$CTR" bash -c "
  set -e
  WS=/tmp/aris-smoke-ros2-ws
  rm -rf \$WS && mkdir -p \$WS/src
  cd \$WS/src
  source /opt/ros/$DISTRO/setup.bash
  ros2 pkg create --build-type ament_cmake smoke_pkg --dependencies rclcpp >/dev/null
  cat > smoke_pkg/src/hello.cpp <<'HELLO'
#include <rclcpp/rclcpp.hpp>
int main(int argc, char **argv){
  rclcpp::init(argc, argv);
  auto node = std::make_shared<rclcpp::Node>(\"smoke_node\");
  RCLCPP_INFO(node->get_logger(), \"hello\");
  rclcpp::shutdown();
  return 0;
}
HELLO
  sed -i '/^find_package(rclcpp REQUIRED)/a add_executable(hello src/hello.cpp)\nament_target_dependencies(hello rclcpp)\ninstall(TARGETS hello DESTINATION lib/\${PROJECT_NAME})' smoke_pkg/CMakeLists.txt
  cd \$WS
  colcon build --packages-select smoke_pkg 2>&1 | tail -5
" 2>&1 | tail -8

if docker exec "$CTR" test -d /tmp/aris-smoke-ros2-ws/install/smoke_pkg; then
  pass "smoke_pkg built — install/smoke_pkg/ present"
else
  fail "smoke_pkg build did not produce install/"
fi

docker exec "$CTR" test -x /tmp/aris-smoke-ros2-ws/install/smoke_pkg/lib/smoke_pkg/hello || fail "hello binary missing"
pass "hello binary built and installed"

docker exec "$CTR" rm -rf /tmp/aris-smoke-ros2-ws

echo "[smoke_ros2_build] ALL PASS"
