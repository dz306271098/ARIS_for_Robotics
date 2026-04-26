#!/usr/bin/env bash
# smoke_cuda_profile.sh — Verify Nsight Compute (ncu) + Nsight Systems (nsys)
# are callable inside the user-provided test container.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$SCRIPT_DIR/_helpers.sh"

pass() { echo "  ✓ $*"; }
fail() { echo "  ✗ $*" >&2; exit 1; }
skip() { echo "  ⊘ $*"; }

echo "[smoke_cuda_profile]"

CTR="$(aris_resolve_test_container "$REPO_ROOT")"
if [[ -z "$CTR" ]] || ! aris_container_running "$CTR"; then
  skip "test container not available"; echo "[smoke_cuda_profile] ALL PASS (skipped)"; exit 0
fi

docker exec "$CTR" test -x /usr/local/cuda/bin/ncu || fail "ncu not found"
docker exec "$CTR" test -x /usr/local/cuda/bin/nsys || fail "nsys not found"
pass "ncu + nsys present"

NCU_VER=$(docker exec "$CTR" /usr/local/cuda/bin/ncu --version 2>&1 | head -2 | tail -1)
NSYS_VER=$(docker exec "$CTR" /usr/local/cuda/bin/nsys --version 2>&1 | head -2 | tail -1)
pass "ncu: $NCU_VER"
pass "nsys: $NSYS_VER"

if docker exec "$CTR" bash -c "ls /proc/driver/nvidia/gpus/ 2>/dev/null" | grep -q "0000:"; then
  pass "GPU device node exposed"
else
  skip "no GPU devices visible — runtime profiling test skipped"
fi

echo "[smoke_cuda_profile] ALL PASS"
