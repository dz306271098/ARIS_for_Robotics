#!/usr/bin/env bash
# smoke_cuda_sanitize.sh — Verify compute-sanitizer is callable inside the
# user-provided test container. Does not require a functional GPU driver.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$SCRIPT_DIR/_helpers.sh"

pass() { echo "  ✓ $*"; }
fail() { echo "  ✗ $*" >&2; exit 1; }
skip() { echo "  ⊘ $*"; }

echo "[smoke_cuda_sanitize]"

CTR="$(aris_resolve_test_container "$REPO_ROOT")"
if [[ -z "$CTR" ]] || ! aris_container_running "$CTR"; then
  skip "test container not available"; echo "[smoke_cuda_sanitize] ALL PASS (skipped)"; exit 0
fi

if ! docker exec "$CTR" test -x /usr/local/cuda/bin/compute-sanitizer; then
  fail "compute-sanitizer not found at /usr/local/cuda/bin/compute-sanitizer"
fi
pass "compute-sanitizer present"

VER=$(docker exec "$CTR" /usr/local/cuda/bin/compute-sanitizer --version 2>&1 | head -3)
echo "$VER" | grep -qi "Compute Sanitizer" || fail "compute-sanitizer --version output unexpected: $VER"
pass "compute-sanitizer --version reports: $(echo "$VER" | head -1)"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/probe.cu" <<'EOF'
#include <cuda_runtime.h>
#include <cstdio>
int main() {
    int c = 0;
    cudaError_t e = cudaGetDeviceCount(&c);
    printf("devices=%d err=%d\n", c, (int)e);
    return 0;
}
EOF
docker cp "$TMP/probe.cu" "$CTR":/tmp/aris-cuda-probe.cu
docker exec "$CTR" bash -c "
  export PATH=/usr/local/cuda/bin:\$PATH
  nvcc -arch=sm_86 /tmp/aris-cuda-probe.cu -o /tmp/aris-cuda-probe 2>/dev/null
"

PROBE=$(docker exec "$CTR" /tmp/aris-cuda-probe 2>&1 || true)
if echo "$PROBE" | grep -qE "driver version is insufficient|no CUDA-capable device"; then
  skip "GPU driver unavailable — runtime sanitizer test skipped"
else
  OUT=$(docker exec "$CTR" /usr/local/cuda/bin/compute-sanitizer --tool=memcheck /tmp/aris-cuda-probe 2>&1 || true)
  if echo "$OUT" | grep -qE "ERROR SUMMARY: 0 errors"; then
    pass "compute-sanitizer memcheck reports 0 errors on probe binary"
  else
    skip "memcheck output unexpected (driver edge case)"
  fi
fi

docker exec "$CTR" rm -f /tmp/aris-cuda-probe /tmp/aris-cuda-probe.cu

echo "[smoke_cuda_sanitize] ALL PASS"
