#!/usr/bin/env bash
# smoke_tensorrt_presence.sh — Verify TensorRT + cuDNN presence inside the
# user-provided test container. Optional — only meaningful when the user
# declares `frameworks: [tensorrt]` in their project contract.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$SCRIPT_DIR/_helpers.sh"

pass() { echo "  ✓ $*"; }
fail() { echo "  ✗ $*" >&2; exit 1; }
skip() { echo "  ⊘ $*"; }

echo "[smoke_tensorrt_presence]"

CTR="$(aris_resolve_test_container "$REPO_ROOT")"
if [[ -z "$CTR" ]] || ! aris_container_running "$CTR"; then
  skip "test container not available"; echo "[smoke_tensorrt_presence] ALL PASS (skipped)"; exit 0
fi

NVINFER=$(docker exec "$CTR" bash -c "dpkg -l 2>/dev/null | grep -c '^ii.*libnvinfer-dev'" 2>&1 || echo 0)
if (( NVINFER >= 1 )); then
  pass "libnvinfer-dev present"
else
  skip "libnvinfer-dev not installed (test container may lack TensorRT — OK unless you use /tensorrt-engine-audit)"
  echo "[smoke_tensorrt_presence] ALL PASS (skipped)"; exit 0
fi

if docker exec "$CTR" bash -c "ls /usr/src/tensorrt/bin/trtexec 2>/dev/null || which trtexec 2>/dev/null || true" | head -1 | grep -q .; then
  pass "trtexec available"
else
  skip "trtexec binary not on standard path"
fi

CUDNN=$(docker exec "$CTR" bash -c "dpkg -l 2>/dev/null | grep -cE '^ii.*cudnn[0-9]'" 2>&1 || echo 0)
(( CUDNN >= 1 )) && pass "cuDNN present" || skip "cuDNN not installed"

echo "[smoke_tensorrt_presence] ALL PASS"
