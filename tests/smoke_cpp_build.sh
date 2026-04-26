#!/usr/bin/env bash
# smoke_cpp_build.sh — Build a minimal CMake C++ project and verify the
# project_contract.py get-build-cmd flow executes end-to-end on the host.
#
# Does not exercise the full /cpp-build skill (which would need an LLM);
# instead validates that the contract-derived build command succeeds on a
# trivial project. Skips gracefully if cmake / g++ not present.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

pass() { echo "  ✓ $*"; }
fail() { echo "  ✗ $*" >&2; exit 1; }
skip() { echo "  ⊘ $*"; }

echo "[smoke_cpp_build]"

# Toolchain presence
if ! command -v cmake >/dev/null 2>&1 || ! command -v g++ >/dev/null 2>&1; then
  skip "cmake or g++ missing — skipping build execution"
  echo "[smoke_cpp_build] ALL PASS (skipped — toolchain missing)"
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Minimal CMake project
cat > "$TMP/CMakeLists.txt" <<'EOF'
cmake_minimum_required(VERSION 3.14)
project(smoke_cpp_build CXX)
add_executable(app main.cpp)
EOF
cat > "$TMP/main.cpp" <<'EOF'
int main() { return 0; }
EOF

# Initialize contract
python3 "$REPO_ROOT/tools/project_contract.py" --root "$TMP" init --language cpp --overwrite >/dev/null
pass "contract initialized"

# Derive build cmd
BUILD_CMD=$(python3 "$REPO_ROOT/tools/project_contract.py" --root "$TMP" get-build-cmd)
echo "$BUILD_CMD" | grep -q "cmake" || fail "contract-derived build cmd should include cmake: $BUILD_CMD"
pass "build-cmd: $BUILD_CMD"

# Execute it
cd "$TMP"
eval "$BUILD_CMD" >build.log 2>&1 || { cat build.log >&2; fail "build failed"; }
pass "minimal CMake project builds via contract-derived cmd"

# Verify binary exists
[[ -x "$TMP/build/app" ]] || fail "executable not produced at build/app"
pass "executable produced"

echo "[smoke_cpp_build] ALL PASS"
