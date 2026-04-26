#!/usr/bin/env bash
# container_run.sh — Canonical container dispatcher for ARIS build-system contract.
#
# Parses .aris/container.yaml, auto-detects runtime among {docker, podman, distrobox,
# toolbx}, and dispatches the given command inside the configured container with the
# declared pre_exec, mounts, env, and workdir. Preserves exit code.
#
# Usage:
#   container_run.sh [--root <path>] [--dry-run] [--probe] [--] <cmd> [args...]
#
# Exit codes:
#   0   success (command inside container returned 0)
#   N   N = exit code of command inside container
#   2   CLI usage error
#   3   .aris/container.yaml missing or malformed
#   4   no supported runtime found
#   5   configured container does not exist / is not running
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="."
DRY_RUN=0
PROBE=0

die() { echo "ERROR: $*" >&2; exit "${2:-1}"; }
say() { [[ "${QUIET:-0}" == "1" ]] || echo "$*" >&2; }

# ---------- Arg parsing ----------

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --probe) PROBE=1; shift ;;
    --quiet) QUIET=1; shift ;;
    -h|--help)
      sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    --) shift; break ;;
    *) break ;;
  esac
done

ROOT="$(cd "$ROOT" && pwd)"
CFG="$ROOT/.aris/container.yaml"
PC_PY="$SCRIPT_DIR/project_contract.py"

# Container config can come from either CLAUDE.md `## Container` section
# (preferred — same UX as `## Remote Server` etc.) or the legacy
# .aris/container.yaml file. We resolve via project_contract.py get-container,
# which checks CLAUDE.md first then the YAML.
load_container_json() {
  python3 "$PC_PY" --root "$ROOT" get-container 2>/dev/null
}

# ---------- Runtime detection ----------

detect_runtime() {
  for rt in docker podman distrobox toolbox; do
    if command -v "$rt" >/dev/null 2>&1; then
      echo "$rt"
      return 0
    fi
  done
  return 1
}

# ---------- YAML parsing (delegated to python for correctness) ----------

yaml_get() {
  # yaml_get <yaml_file> <dotted.key>
  # Prints the value; empty string if missing.
  local f="$1" k="$2"
  python3 - "$f" "$k" <<'PY'
import sys, json
path, key = sys.argv[1], sys.argv[2]
try:
    import yaml
    with open(path) as fh:
        cfg = yaml.safe_load(fh) or {}
except ImportError:
    # Minimal fallback — reuse project_contract's parser via import.
    sys.path.insert(0, __import__("os").path.dirname(path.rstrip("/")) + "/../tools")
    # As a last resort, a very narrow parse; ARIS authors know to install PyYAML for production.
    cfg = {}
    with open(path) as fh:
        for line in fh:
            line = line.rstrip()
            if line and ":" in line and not line.startswith(" ") and not line.startswith("#"):
                kk, _, vv = line.partition(":")
                cfg[kk.strip()] = vv.strip()
cur = cfg
for part in key.split("."):
    if isinstance(cur, dict) and part in cur:
        cur = cur[part]
    else:
        print("")
        sys.exit(0)
if isinstance(cur, (list, dict)):
    print(json.dumps(cur))
else:
    print("" if cur is None else cur)
PY
}

yaml_list() {
  # yaml_list <yaml_file> <dotted.key>  -> newline-separated items
  local f="$1" k="$2"
  python3 - "$f" "$k" <<'PY'
import sys, json
path, key = sys.argv[1], sys.argv[2]
try:
    import yaml
    with open(path) as fh:
        cfg = yaml.safe_load(fh) or {}
except ImportError:
    cfg = {}
cur = cfg
for part in key.split("."):
    if isinstance(cur, dict) and part in cur:
        cur = cur[part]
    else:
        sys.exit(0)
if isinstance(cur, list):
    for item in cur:
        if isinstance(item, dict):
            print(json.dumps(item))
        else:
            print(item)
PY
}

# ---------- Probe mode ----------

if [[ "$PROBE" == "1" ]]; then
  rt="$(detect_runtime || true)"
  if [[ -z "$rt" ]]; then
    echo "no container runtime found (looked for docker / podman / distrobox / toolbox)" >&2
    exit 4
  fi
  echo "runtime: $rt"
  case "$rt" in
    docker|podman) "$rt" ps --format '{{.Names}}' 2>/dev/null | head -10 ;;
    distrobox) distrobox list 2>/dev/null | tail -n+2 | head -10 ;;
    toolbox) toolbox list -c 2>/dev/null | tail -n+2 | head -10 ;;
  esac
  exit 0
fi

# ---------- Normal dispatch ----------

CTR_JSON="$(load_container_json)"
if [[ -z "$CTR_JSON" || "$CTR_JSON" == "{}" ]]; then
  die "no container config found — author one in CLAUDE.md (## Container section) or .aris/container.yaml; see shared-references/build-system-contract.md" 3
fi

RUNTIME_CFG="$(echo "$CTR_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("runtime",""))')"
CONTAINER_NAME="$(echo "$CTR_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("name",""))')"
WORKDIR="$(echo "$CTR_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("workdir","/workspace"))')"

if [[ -z "$CONTAINER_NAME" ]]; then
  die "container.name not set in CLAUDE.md ## Container or .aris/container.yaml" 3
fi

if [[ -z "$RUNTIME_CFG" || "$RUNTIME_CFG" == "auto" ]]; then
  RUNTIME="$(detect_runtime || true)"
  [[ -z "$RUNTIME" ]] && die "no supported container runtime found" 4
else
  RUNTIME="$RUNTIME_CFG"
  command -v "$RUNTIME" >/dev/null 2>&1 || die "runtime '$RUNTIME' not found in PATH" 4
fi

# ---------- Ensure container exists / is usable ----------

container_running() {
  case "$RUNTIME" in
    docker|podman)
      "$RUNTIME" ps --format '{{.Names}}' 2>/dev/null | grep -qx "$CONTAINER_NAME"
      ;;
    distrobox|toolbox)
      "$RUNTIME" list 2>/dev/null | grep -qw "$CONTAINER_NAME"
      ;;
    *) return 1 ;;
  esac
}

if [[ "$DRY_RUN" != "1" ]]; then
  if ! container_running; then
    say "container '$CONTAINER_NAME' not running; attempting to start..."
    case "$RUNTIME" in
      docker|podman)
        "$RUNTIME" start "$CONTAINER_NAME" >/dev/null 2>&1 || die "cannot start $CONTAINER_NAME (does it exist?)" 5
        ;;
      distrobox|toolbox)
        : ;;  # distrobox-enter / toolbox run auto-start
    esac
  fi
fi

# ---------- Collect pre_exec + env ----------

PRE_EXEC_LINES=()
while IFS= read -r line; do
  [[ -n "$line" ]] && PRE_EXEC_LINES+=("$line")
done < <(echo "$CTR_JSON" | python3 -c '
import json, sys
data = json.load(sys.stdin)
pe = data.get("pre_exec", [])
if isinstance(pe, str):
    pe = [pe]
for line in pe or []:
    if line:
        print(line)
')

ENV_PAIRS=()
while IFS= read -r pair; do
  [[ -n "$pair" ]] && ENV_PAIRS+=("$pair")
done < <(echo "$CTR_JSON" | python3 -c '
import json, sys
data = json.load(sys.stdin)
env = data.get("env", {})
if isinstance(env, dict):
    for k, v in env.items():
        print(f"{k}={v}")
')

# ---------- Build the in-container command ----------

if [[ $# -eq 0 ]]; then
  die "no command provided" 2
fi

CMD_STR=""
for arg in "$@"; do
  CMD_STR+="$(printf '%q' "$arg") "
done
CMD_STR="${CMD_STR% }"

PRE_BLOCK=""
for l in "${PRE_EXEC_LINES[@]}"; do
  PRE_BLOCK+="$l"$'\n'
done

# ---------- Dispatch ----------

case "$RUNTIME" in
  docker|podman)
    ENV_FLAGS=()
    for pair in "${ENV_PAIRS[@]}"; do
      ENV_FLAGS+=("-e" "$pair")
    done
    # Ensure workdir exists before dispatch (host mount may be absent).
    CMD_ARR=("$RUNTIME" "exec" "${ENV_FLAGS[@]}" "$CONTAINER_NAME" "bash" "-lc" "mkdir -p $(printf '%q' "$WORKDIR") && cd $(printf '%q' "$WORKDIR") && ${PRE_BLOCK}${CMD_STR}")
    ;;
  distrobox)
    CMD_ARR=("distrobox-enter" "--name" "$CONTAINER_NAME" "--" "bash" "-lc" "mkdir -p $(printf '%q' "$WORKDIR") && cd $(printf '%q' "$WORKDIR") && ${PRE_BLOCK}${CMD_STR}")
    ;;
  toolbox)
    CMD_ARR=("toolbox" "run" "-c" "$CONTAINER_NAME" "bash" "-lc" "mkdir -p $(printf '%q' "$WORKDIR") && cd $(printf '%q' "$WORKDIR") && ${PRE_BLOCK}${CMD_STR}")
    ;;
  *)
    die "unhandled runtime: $RUNTIME" 4
    ;;
esac

if [[ "$DRY_RUN" == "1" ]]; then
  printf '%q ' "${CMD_ARR[@]}"
  echo
  exit 0
fi

exec "${CMD_ARR[@]}"
