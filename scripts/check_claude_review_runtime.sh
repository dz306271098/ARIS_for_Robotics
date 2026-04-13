#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SERVER_PATH="$REPO_ROOT/mcp-servers/claude-review/server.py"
MCP_NAME="${CLAUDE_REVIEW_MCP_NAME:-claude-review}"

PRIMARY_MODEL="${CLAUDE_REVIEW_MODEL:-claude-opus-4-6[1m]}"
FALLBACK_MODEL="${CLAUDE_REVIEW_FALLBACK_MODEL:-claude-opus-4-6}"
PROXY_ENV_KEYS=(http_proxy https_proxy no_proxy HTTP_PROXY HTTPS_PROXY NO_PROXY all_proxy ALL_PROXY)

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/claude-review-runtime.XXXXXX")"
MCP_JSON="$TEMP_DIR/mcp.json"
HOST_SCHEMA="$TEMP_DIR/host-mcp-schema.json"
HOST_OUTPUT="$TEMP_DIR/host-mcp-output.json"
declare -a SHELL_PROXY_KEYS=()
declare -a MCP_PROXY_KEYS=()
declare -a MISSING_PROXY_KEYS=()

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

require_command claude
require_command codex
require_command python3

join_by_space() {
  local first=1
  local item
  for item in "$@"; do
    if (( first )); then
      printf '%s' "$item"
      first=0
    else
      printf ' %s' "$item"
    fi
  done
}

for key in "${PROXY_ENV_KEYS[@]}"; do
  if [[ -n "${!key-}" ]]; then
    SHELL_PROXY_KEYS+=("$key")
  fi
done

codex mcp get "$MCP_NAME" --json > "$MCP_JSON"
mapfile -t MCP_PROXY_KEYS < <(
  python3 - "$MCP_JSON" <<'PY'
import json
import sys

proxy_keys = (
    "http_proxy",
    "https_proxy",
    "no_proxy",
    "HTTP_PROXY",
    "HTTPS_PROXY",
    "NO_PROXY",
    "all_proxy",
    "ALL_PROXY",
)
payload = json.load(open(sys.argv[1], encoding="utf-8"))
env = payload.get("transport", {}).get("env", {})
for key in proxy_keys:
    if env.get(key):
        print(key)
PY
)

declare -A mcp_proxy_seen=()
for key in "${MCP_PROXY_KEYS[@]}"; do
  mcp_proxy_seen["$key"]=1
done
for key in "${SHELL_PROXY_KEYS[@]}"; do
  if [[ -z "${mcp_proxy_seen[$key]-}" ]]; then
    MISSING_PROXY_KEYS+=("$key")
  fi
done

echo "== Proxy environment =="
if (( ${#SHELL_PROXY_KEYS[@]} > 0 )); then
  echo "Current shell proxy env keys: $(join_by_space "${SHELL_PROXY_KEYS[@]}")"
else
  echo "Current shell proxy env keys: none"
fi
if (( ${#MCP_PROXY_KEYS[@]} > 0 )); then
  echo "Registered MCP proxy env keys: $(join_by_space "${MCP_PROXY_KEYS[@]}")"
else
  echo "Registered MCP proxy env keys: none"
fi
if (( ${#MISSING_PROXY_KEYS[@]} > 0 )); then
  echo "MCP config is missing proxy env keys from the current shell: $(join_by_space "${MISSING_PROXY_KEYS[@]}")"
fi

echo "== Claude auth status =="
claude auth status --json

echo
echo "== Direct primary model =="
claude -p "Reply with exactly: DIRECT_PRIMARY_OK" \
  --output-format json \
  --permission-mode plan \
  --model "$PRIMARY_MODEL" \
  --tools ""

if [[ "$FALLBACK_MODEL" != "$PRIMARY_MODEL" ]]; then
  echo
  echo "== Direct fallback model =="
  claude -p "Reply with exactly: DIRECT_FALLBACK_OK" \
    --output-format json \
    --permission-mode plan \
    --model "$FALLBACK_MODEL" \
    --tools ""
fi

echo
echo "== Direct bridge default chain =="
CLAUDE_REVIEW_MODEL="$PRIMARY_MODEL" \
CLAUDE_REVIEW_FALLBACK_MODEL="$FALLBACK_MODEL" \
python3 - "$SERVER_PATH" <<'PY'
import json
import os
import subprocess
import sys

server_path = sys.argv[1]
env = dict(os.environ)
proc = subprocess.Popen(
    [sys.executable, server_path],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True,
    env=env,
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
    if init.get("result", {}).get("serverInfo", {}).get("name") != "claude-review":
        raise RuntimeError(f"Unexpected initialize response: {init}")

    result = call(
        {
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/call",
            "params": {
                "name": "review",
                "arguments": {"prompt": "Reply with exactly: DIRECT_SERVER_OK"},
            },
        }
    )
    payload = json.loads(result["result"]["content"][0]["text"])
    if payload.get("response") != "DIRECT_SERVER_OK":
        raise RuntimeError(f"Unexpected bridge review response: {payload}")
    print(json.dumps(payload, ensure_ascii=False, indent=2))
finally:
    proc.terminate()
    proc.wait(timeout=5)
PY

echo
echo "== Installed MCP via host Codex exec =="
cat > "$HOST_SCHEMA" <<'JSON'
{
  "type": "object",
  "properties": {
    "response": { "type": "string" },
    "model": { "type": "string" },
    "tool_status": { "type": "string", "enum": ["ok", "error"] }
  },
  "required": ["response", "model", "tool_status"],
  "additionalProperties": false
}
JSON

host_exec_status=0
if codex exec \
  --dangerously-bypass-approvals-and-sandbox \
  -C "$REPO_ROOT" \
  --output-schema "$HOST_SCHEMA" \
  -o "$HOST_OUTPUT" \
  "Use the MCP tool mcp__claude_review__review exactly once with prompt 'Reply with exactly: INSTALLED_MCP_OK'. Do not run shell commands. Return JSON with keys response, model, and tool_status. Set tool_status to 'ok' only if the MCP call succeeds, and copy the tool's response and model fields into response and model. If the MCP call fails, set tool_status to 'error', set response to the error text, and set model to an empty string." >/dev/null; then
  :
else
  host_exec_status=$?
fi

if [[ ! -s "$HOST_OUTPUT" ]]; then
  echo "Installed MCP check failed: codex exec returned status $host_exec_status and produced no structured output." >&2
  if (( ${#MISSING_PROXY_KEYS[@]} > 0 )); then
    echo "Current shell proxy env keys are missing from the installed MCP config." >&2
    echo "Reinstall with: bash scripts/install_codex_claude_mainline.sh --reinstall" >&2
  fi
  exit 1
fi

python3 - "$HOST_OUTPUT" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload.get("tool_status") != "ok":
    raise RuntimeError(f"Installed MCP check reported tool_status=error: {payload}")
if payload.get("response") != "INSTALLED_MCP_OK":
    raise RuntimeError(f"Installed MCP response mismatch: {payload}")
print(json.dumps(payload, ensure_ascii=False, indent=2))
PY

echo
echo "Runtime checks passed."
