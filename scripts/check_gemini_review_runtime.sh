#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SERVER_PATH="$REPO_ROOT/mcp-servers/gemini-review/server.py"
MCP_NAME="${GEMINI_REVIEW_MCP_NAME:-gemini-review}"
MODEL="${GEMINI_REVIEW_MODEL:-gemini-3.1-pro-preview}"
BACKEND="${GEMINI_REVIEW_BACKEND:-cli}"
TIMEOUT_SEC="${GEMINI_REVIEW_TIMEOUT_SEC:-180}"
HOST_REQUIRED=0
SKIP_INSTALLED_MCP_CHECK=0

usage() {
  cat <<'EOF'
Usage: check_gemini_review_runtime.sh [options]

Options:
  --host-required              Fail if the script appears to run inside Codex/bwrap sandbox
  --skip-installed-mcp-check   Skip the installed Codex MCP check
  --mcp-name NAME              Installed MCP name to check (default: gemini-review)
  --model MODEL                Gemini CLI model to check (default: gemini-3.1-pro-preview)
  --timeout-sec SECONDS        Direct CLI timeout (default: 180)
  -h, --help                   Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host-required)
      HOST_REQUIRED=1
      shift
      ;;
    --skip-installed-mcp-check)
      SKIP_INSTALLED_MCP_CHECK=1
      shift
      ;;
    --mcp-name)
      [[ $# -ge 2 ]] || { echo "Missing value for --mcp-name" >&2; exit 1; }
      MCP_NAME="$2"
      shift 2
      ;;
    --model)
      [[ $# -ge 2 ]] || { echo "Missing value for --model" >&2; exit 1; }
      MODEL="$2"
      shift 2
      ;;
    --timeout-sec)
      [[ $# -ge 2 ]] || { echo "Missing value for --timeout-sec" >&2; exit 1; }
      TIMEOUT_SEC="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/gemini-review-runtime.XXXXXX")"
DIRECT_OUTPUT="$TEMP_DIR/direct-output.json"
DIRECT_STDERR="$TEMP_DIR/direct-stderr.txt"
DIRECT_BRIDGE_OUTPUT="$TEMP_DIR/direct-bridge.json"
HOST_SCHEMA="$TEMP_DIR/host-mcp-schema.json"
HOST_OUTPUT="$TEMP_DIR/host-mcp-output.json"
NESTED_HOME="$TEMP_DIR/nested-home"

cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

require_command() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "Required command not found: $name" >&2
    exit 1
  fi
}

detect_codex_sandbox() {
  if [[ -n "${CODEX_CI:-}" || -n "${CODEX_SANDBOX:-}" ]]; then
    return 0
  fi

  local pid="$$"
  local depth=0
  while [[ "$pid" =~ ^[0-9]+$ ]] && (( pid > 1 )) && (( depth < 32 )); do
    local args=""
    args="$(ps -o args= -p "$pid" 2>/dev/null || true)"
    if [[ "$args" == *"codex-linux-sandbox"* || "$args" == *"sandbox-policy"* || "$args" == *"bwrap --new-session"* ]]; then
      return 0
    fi
    pid="$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ' || true)"
    depth=$((depth + 1))
  done
  return 1
}

summarize_failure() {
  local stdout_path="$1"
  local stderr_path="$2"
  python3 - "$stdout_path" "$stderr_path" <<'PY'
import json
import re
import sys
from pathlib import Path

texts = []
for raw_path in sys.argv[1:]:
    path = Path(raw_path)
    if path.exists():
        text = path.read_text(encoding="utf-8", errors="replace").strip()
        if text:
            texts.append(text)

joined = "\n".join(texts)
if not joined:
    print("no stdout/stderr captured")
    raise SystemExit(0)

for text in texts:
    try:
        payload = json.loads(text)
    except json.JSONDecodeError:
        continue
    if isinstance(payload, dict):
        error = payload.get("error")
        if isinstance(error, dict) and error.get("message"):
            print(error["message"])
            raise SystemExit(0)
        response = payload.get("response")
        if isinstance(response, str) and response.strip():
            print(response.strip())
            raise SystemExit(0)

if "MODEL_CAPACITY_EXHAUSTED" in joined or "No capacity available" in joined:
    print("MODEL_CAPACITY_EXHAUSTED | No capacity available for requested Gemini model in this execution environment")
    raise SystemExit(0)
if "Manual authorization is required" in joined:
    print("AUTH_REQUIRED | run Gemini CLI login in the host environment")
    raise SystemExit(0)
if "invalid_grant" in joined or "Unauthorized" in joined:
    print("AUTH_FAILED | Gemini CLI authorization failed")
    raise SystemExit(0)

message_match = re.search(r'"message"\s*:\s*"([^"]+)"', joined)
if message_match:
    print(message_match.group(1))
    raise SystemExit(0)

one_line = " ".join(joined.split())
print(one_line[:2000] + ("..." if len(one_line) > 2000 else ""))
PY
}

if detect_codex_sandbox; then
  echo "Detected Codex/bwrap sandbox ancestry."
  if (( HOST_REQUIRED )); then
    echo "Host-required Gemini reviewer checks must be run from the host environment, not from this sandbox." >&2
    exit 1
  fi
  echo "Continuing as sandbox diagnostic only; do not treat this result as host reviewer availability."
fi

require_command gemini
require_command python3
if (( SKIP_INSTALLED_MCP_CHECK == 0 )); then
  require_command codex
fi

echo "== Gemini runtime context =="
echo "gemini_bin: $(command -v gemini)"
echo "gemini_version: $(gemini --version)"
echo "model: $MODEL"
echo "backend: $BACKEND"
echo "HOME: $HOME"
echo "GEMINI_CLI_HOME: ${GEMINI_CLI_HOME:-<unset>}"
proxy_keys=()
for key in http_proxy https_proxy no_proxy HTTP_PROXY HTTPS_PROXY NO_PROXY all_proxy ALL_PROXY; do
  if [[ -n "${!key-}" ]]; then
    proxy_keys+=("$key")
  fi
done
if (( ${#proxy_keys[@]} )); then
  echo "proxy_env_keys: ${proxy_keys[*]}"
else
  echo "proxy_env_keys: <none>"
fi

echo
echo "== Direct Gemini CLI =="
direct_status=0
if timeout "$TIMEOUT_SEC" gemini -p "Reply with exactly: GEMINI_DIRECT_OK" \
  --output-format json \
  -m "$MODEL" >"$DIRECT_OUTPUT" 2>"$DIRECT_STDERR" < /dev/null; then
  :
else
  direct_status=$?
fi

if (( direct_status != 0 )); then
  echo "Direct Gemini CLI check failed with status $direct_status." >&2
  summarize_failure "$DIRECT_OUTPUT" "$DIRECT_STDERR" >&2
  exit 1
fi

python3 - "$DIRECT_OUTPUT" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
response = str(payload.get("response", "")).strip()
if response != "GEMINI_DIRECT_OK":
    raise RuntimeError(f"Unexpected Gemini direct response: {payload}")
print(json.dumps({"response": response, "session_id": payload.get("session_id", "")}, ensure_ascii=False, indent=2))
PY

echo
echo "== Direct Gemini MCP bridge =="
GEMINI_REVIEW_BACKEND="$BACKEND" \
GEMINI_REVIEW_MODEL="$MODEL" \
GEMINI_REVIEW_TIMEOUT_SEC="$TIMEOUT_SEC" \
python3 - "$SERVER_PATH" "$DIRECT_BRIDGE_OUTPUT" <<'PY'
import json
import os
import subprocess
import sys
from pathlib import Path

server_path = sys.argv[1]
output_path = Path(sys.argv[2])
proc = subprocess.Popen(
    [sys.executable, server_path],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True,
    env=dict(os.environ),
)


def call(payload: dict) -> dict:
    assert proc.stdin is not None
    assert proc.stdout is not None
    proc.stdin.write(json.dumps(payload) + "\n")
    proc.stdin.flush()
    line = proc.stdout.readline()
    if not line:
        stderr = ""
        if proc.stderr is not None:
            stderr = proc.stderr.read().strip()
        raise RuntimeError(f"Server returned no output. stderr: {stderr}")
    return json.loads(line)


try:
    init = call({"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}})
    if init.get("result", {}).get("serverInfo", {}).get("name") != "gemini-review":
        raise RuntimeError(f"Unexpected initialize response: {init}")
    result = call(
        {
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/call",
            "params": {
                "name": "review",
                "arguments": {"prompt": "Reply with exactly: GEMINI_BRIDGE_OK"},
            },
        }
    )
    content = result.get("result", {}).get("content", [{}])[0].get("text", "{}")
    payload = json.loads(content)
    if result.get("result", {}).get("isError"):
        raise RuntimeError(payload.get("error", payload))
    response = str(payload.get("response", "")).strip()
    if response != "GEMINI_BRIDGE_OK":
        raise RuntimeError(f"Unexpected bridge response: {payload}")
    output_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
finally:
    proc.terminate()
    proc.wait(timeout=5)
PY
cat "$DIRECT_BRIDGE_OUTPUT"

if (( SKIP_INSTALLED_MCP_CHECK )); then
  echo
  echo "Skipping installed MCP check."
  echo "Gemini runtime checks passed."
  exit 0
fi

echo
echo "== Installed Gemini MCP via host Codex exec =="
codex mcp get "$MCP_NAME" --json >/dev/null

cat > "$HOST_SCHEMA" <<'JSON'
{
  "type": "object",
  "properties": {
    "response": { "type": "string" },
    "model": { "type": "string" },
    "backend": { "type": "string" },
    "tool_status": { "type": "string", "enum": ["ok", "error"] }
  },
  "required": ["response", "model", "backend", "tool_status"],
  "additionalProperties": false
}
JSON

mkdir -p "$NESTED_HOME/.codex"
if [[ -d "$HOME/.codex" ]]; then
  for entry in config.toml auth.json credentials.json mcp-servers skills plugins; do
    if [[ -e "$HOME/.codex/$entry" ]]; then
      cp -a "$HOME/.codex/$entry" "$NESTED_HOME/.codex/"
    fi
  done
fi
if [[ -d "$HOME/.gemini" ]]; then
  cp -a "$HOME/.gemini" "$NESTED_HOME/.gemini"
fi

host_exec_status=0
if HOME="$NESTED_HOME" codex exec \
  --dangerously-bypass-approvals-and-sandbox \
  -C "$REPO_ROOT" \
  --output-schema "$HOST_SCHEMA" \
  -o "$HOST_OUTPUT" \
  "This is a pure host MCP connectivity check. Do not run shell commands. Use mcp__gemini_review__review exactly once with prompt 'Reply with exactly: GEMINI_INSTALLED_MCP_OK'. Return JSON with keys response, model, backend, and tool_status. Set tool_status to 'ok' only if the MCP call succeeds, and copy response/model/backend from the tool response. If it fails, set tool_status to 'error', response to the error text, model to empty string, and backend to empty string." >/dev/null; then
  :
else
  host_exec_status=$?
fi

if [[ ! -s "$HOST_OUTPUT" ]]; then
  echo "Installed Gemini MCP check failed: codex exec returned status $host_exec_status and produced no structured output." >&2
  exit 1
fi

python3 - "$HOST_OUTPUT" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload.get("tool_status") != "ok":
    raise RuntimeError(f"Installed MCP check reported tool_status=error: {payload}")
response = payload.get("response", "")
if "GEMINI_INSTALLED_MCP_OK" not in response:
    raise RuntimeError(f"Installed MCP response mismatch: {payload}")
print(json.dumps(payload, ensure_ascii=False, indent=2))
PY

echo
echo "Gemini runtime checks passed."
