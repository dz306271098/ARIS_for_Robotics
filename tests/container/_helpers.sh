#!/usr/bin/env bash
# tests/container/_helpers.sh — Shared helpers for ARIS container-side smoke tests.
#
# Resolves the target container name from (in priority order):
#   1. $ARIS_TEST_CONTAINER env var
#   2. The `name:` field of .aris/container.yaml at repo root, if present
#   3. Skips the test (no default; ARIS does not ship a container)
#
# If resolution succeeds but the container isn't running, the individual test
# emits a SKIP and exits 0 — container validation is opt-in.

aris_resolve_test_container() {
  local repo_root="$1"
  if [[ -n "${ARIS_TEST_CONTAINER:-}" ]]; then
    echo "$ARIS_TEST_CONTAINER"; return 0
  fi
  if [[ -f "$repo_root/.aris/container.yaml" ]]; then
    python3 - "$repo_root/.aris/container.yaml" <<'PY' 2>/dev/null || true
import sys
try:
    import yaml
    cfg = yaml.safe_load(open(sys.argv[1])) or {}
except Exception:
    cfg = {}
    # Minimal parse
    for line in open(sys.argv[1]):
        line = line.rstrip()
        if line.startswith("name:"):
            cfg["name"] = line.split(":",1)[1].strip()
            break
name = cfg.get("name", "")
if name:
    print(name)
PY
    return 0
  fi
  return 0  # empty → caller skips
}

# Returns 0 if container is running, 1 otherwise.
aris_container_running() {
  local name="$1"
  [[ -z "$name" ]] && return 1
  command -v docker >/dev/null 2>&1 || return 1
  docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$name"
}
