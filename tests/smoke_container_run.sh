#!/usr/bin/env bash
# smoke_container_run.sh — Verify container_run.sh parses config + dispatches correctly.
#
# Runs both in dry-run mode (host-only, works everywhere) and, if a docker
# container is present, verifies a real exec via that container ($ARIS_TEST_CONTAINER
# if set, else the first running one).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

pass() { echo "  ✓ $*"; }
fail() { echo "  ✗ $*" >&2; exit 1; }

echo "[smoke_container_run]"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# 1. Missing config → exit 3
if bash "$REPO_ROOT/tools/container_run.sh" --root "$TMP" -- echo hello >/dev/null 2>&1; then
  fail "expected exit 3 when .aris/container.yaml missing"
fi
pass "missing container.yaml → non-zero"

# 2. Probe mode returns a runtime OR errors out with exit 4
PROBE_OUT=$(bash "$REPO_ROOT/tools/container_run.sh" --probe 2>&1 || true)
if command -v docker >/dev/null 2>&1 || command -v podman >/dev/null 2>&1 \
   || command -v distrobox >/dev/null 2>&1 || command -v toolbox >/dev/null 2>&1; then
  echo "$PROBE_OUT" | grep -qE "runtime: (docker|podman|distrobox|toolbox)" || fail "probe did not report a runtime: $PROBE_OUT"
  pass "probe detects runtime"
else
  echo "$PROBE_OUT" | grep -qi "no container runtime" || fail "probe should report none found"
  pass "probe reports no runtime (expected in minimal env)"
fi

# 3. Dry-run with valid config prints a dispatched command
mkdir -p "$TMP/.aris"
cat > "$TMP/.aris/container.yaml" <<'EOF'
runtime: auto
name: nonexistent-test-container
workdir: /tmp/smoke
pre_exec:
  - "export FOO=bar"
env:
  BAZ: "qux"
EOF
# Auto-detect may fail if no runtime; only test when docker is present
if command -v docker >/dev/null 2>&1; then
  OUT=$(bash "$REPO_ROOT/tools/container_run.sh" --root "$TMP" --dry-run -- bash -c "echo ok" 2>&1 || true)
  echo "$OUT" | grep -q "docker exec" || fail "dry-run should echo a docker exec command: $OUT"
  pass "dry-run prints dispatched command"
fi

# 4. Real exec if a test container is configured
# Resolve the test container: $ARIS_TEST_CONTAINER or first running docker
CTR="${ARIS_TEST_CONTAINER:-}"
if [[ -z "$CTR" ]] && command -v docker >/dev/null 2>&1; then
  # Use the first running container as a fallback for smoke purposes
  CTR=$(docker ps --format '{{.Names}}' 2>/dev/null | head -1)
fi
if [[ -n "$CTR" ]] && command -v docker >/dev/null 2>&1 && docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$CTR"; then
  cat > "$TMP/.aris/container.yaml" <<EOF
runtime: docker
name: $CTR
workdir: /tmp/aris-smoke-container-run
pre_exec:
  - "export SMOKE=1"
env:
  TEST_VAR: "smoke"
EOF
  OUT=$(bash "$REPO_ROOT/tools/container_run.sh" --root "$TMP" -- bash -c 'echo "host=$(hostname) var=$TEST_VAR pwd=$(pwd)"' 2>&1)
  echo "$OUT" | grep -q "var=smoke" || fail "env not forwarded: $OUT"
  echo "$OUT" | grep -q "pwd=/tmp/aris-smoke-container-run" || fail "workdir not set: $OUT"
  pass "real docker exec into '$CTR' dispatches with env + workdir"
else
  pass "skipped real exec (no test container configured)"
fi

echo "[smoke_container_run] ALL PASS"
