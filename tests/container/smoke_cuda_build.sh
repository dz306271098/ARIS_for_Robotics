#!/usr/bin/env bash
# smoke_cuda_build.sh — Compile a minimal SAXPY kernel via nvcc inside the
# user-provided test container. Verifies the CUDA toolchain is usable at build
# time, regardless of CUDA toolkit version or GPU arch.
#
# Defaults to -arch=sm_75 (Turing, 2018) — the broadest still-supported
# architecture across CUDA 10 through CUDA 13 (CUDA 13 dropped sm_50/sm_60).
# Override with $ARIS_TEST_SM_ARCH=sm_86 (or whatever your test container's
# nvcc supports). Skipped gracefully if no test container.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$SCRIPT_DIR/_helpers.sh"

pass() { echo "  ✓ $*"; }
fail() { echo "  ✗ $*" >&2; exit 1; }
skip() { echo "  ⊘ $*"; }

echo "[smoke_cuda_build]"

CTR="$(aris_resolve_test_container "$REPO_ROOT")"
if [[ -z "$CTR" ]]; then
  skip "no test container configured (set \$ARIS_TEST_CONTAINER or .aris/container.yaml)"
  echo "[smoke_cuda_build] ALL PASS (skipped)"; exit 0
fi
if ! aris_container_running "$CTR"; then
  skip "test container '$CTR' not running"
  echo "[smoke_cuda_build] ALL PASS (skipped)"; exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/saxpy.cu" <<'EOF'
#include <cuda_runtime.h>
#include <cstdio>
__global__ void saxpy(float a, float *x, float *y, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) y[i] = a * x[i] + y[i];
}
int main() {
    // Compile-time test only — do not launch kernel (no GPU driver needed).
    printf("saxpy kernel symbol: %p\n", (void*)saxpy);
    return 0;
}
EOF

docker cp "$TMP/saxpy.cu" "$CTR":/tmp/aris-smoke-saxpy.cu

# Default to sm_75 (Turing, 2018) — works on CUDA 10/11/12/13. Older arches
# (sm_50/sm_60) were dropped by CUDA 13. User can override via
# $ARIS_TEST_SM_ARCH (e.g. sm_86 for Ampere, sm_89 for Ada, sm_90 for Hopper).
SM_ARCH="${ARIS_TEST_SM_ARCH:-sm_75}"

OUT=$(docker exec "$CTR" bash -c "
  export PATH=/usr/local/cuda/bin:\$PATH
  nvcc -arch=$SM_ARCH -std=c++17 -O3 --ptxas-options=-v /tmp/aris-smoke-saxpy.cu -o /tmp/aris-smoke-saxpy 2>&1
" || true)

if ! echo "$OUT" | grep -qE "Compiling entry function.*saxpy"; then
  echo "$OUT" >&2
  fail "nvcc did not report compiling the saxpy kernel"
fi
pass "nvcc compiles saxpy kernel for $SM_ARCH"

if echo "$OUT" | grep -qE "Used [0-9]+ registers"; then
  REGS=$(echo "$OUT" | grep -oE "Used [0-9]+ registers" | head -1 | awk '{print $2}')
  pass "ptxas reports register usage: $REGS"
else
  skip "register count not extracted (compiler version variation)"
fi

docker exec "$CTR" test -x /tmp/aris-smoke-saxpy || fail "compiled binary not found"
pass "binary artifact present"

docker exec "$CTR" rm -f /tmp/aris-smoke-saxpy /tmp/aris-smoke-saxpy.cu

echo "[smoke_cuda_build] ALL PASS"
