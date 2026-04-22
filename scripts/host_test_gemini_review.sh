#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SERVER_PATH="$REPO_ROOT/mcp-servers/gemini-review/server.py"

MCP_NAME="${GEMINI_REVIEW_MCP_NAME:-gemini-review}"
MODEL="${GEMINI_REVIEW_MODEL:-gemini-3.1-pro-preview}"
TIMEOUT_SEC="${GEMINI_REVIEW_TIMEOUT_SEC:-180}"
MAX_RETRIES="${GEMINI_REVIEW_MAX_RETRIES:-2}"
RETRY_DELAY_SEC="${GEMINI_REVIEW_RETRY_DELAY_SEC:-5}"
EXPECTED="${GEMINI_REVIEW_EXPECTED:-GEMINI_REVIEW_HOST_OK}"
PROMPT="Reply with exactly: $EXPECTED"
CHECK_INSTALLED_MCP=1
ALLOW_SANDBOX=0
TEST_CWD="${GEMINI_REVIEW_TEST_CWD:-$PWD}"

usage() {
  cat <<'EOF'
Usage: host_test_gemini_review.sh [options]

Run this from a real host terminal, not from Codex sandbox.

Options:
  --model MODEL                 Gemini CLI model to test (default: gemini-3.1-pro-preview)
  --timeout-sec SECONDS         Timeout for each Gemini review call (default: 180)
  --max-retries N               Retry count for transient capacity/network failures (default: 2)
  --retry-delay-sec SECONDS     Delay between retries (default: 5)
  --expected TEXT               Exact response expected from Gemini (default: GEMINI_REVIEW_HOST_OK)
  --mcp-name NAME               Installed MCP name to test (default: gemini-review)
  --test-cwd DIR                Working directory for Gemini CLI/MCP calls (default: current dir)
  --skip-installed-mcp          Only test direct CLI and local bridge; skip codex mcp config
  --allow-sandbox               Do not fail when Codex/bwrap sandbox markers are detected
  -h, --help                    Show this help

Examples:
  bash scripts/host_test_gemini_review.sh
  bash scripts/host_test_gemini_review.sh --timeout-sec 300
  GEMINI_REVIEW_MODEL=gemini-3.1-pro-preview bash scripts/host_test_gemini_review.sh
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model)
      [[ $# -ge 2 ]] || { echo "Missing value for --model" >&2; exit 2; }
      MODEL="$2"
      shift 2
      ;;
    --timeout-sec)
      [[ $# -ge 2 ]] || { echo "Missing value for --timeout-sec" >&2; exit 2; }
      TIMEOUT_SEC="$2"
      shift 2
      ;;
    --max-retries)
      [[ $# -ge 2 ]] || { echo "Missing value for --max-retries" >&2; exit 2; }
      MAX_RETRIES="$2"
      shift 2
      ;;
    --retry-delay-sec)
      [[ $# -ge 2 ]] || { echo "Missing value for --retry-delay-sec" >&2; exit 2; }
      RETRY_DELAY_SEC="$2"
      shift 2
      ;;
    --expected)
      [[ $# -ge 2 ]] || { echo "Missing value for --expected" >&2; exit 2; }
      EXPECTED="$2"
      PROMPT="Reply with exactly: $EXPECTED"
      shift 2
      ;;
    --mcp-name)
      [[ $# -ge 2 ]] || { echo "Missing value for --mcp-name" >&2; exit 2; }
      MCP_NAME="$2"
      shift 2
      ;;
    --test-cwd)
      [[ $# -ge 2 ]] || { echo "Missing value for --test-cwd" >&2; exit 2; }
      TEST_CWD="$2"
      shift 2
      ;;
    --skip-installed-mcp)
      CHECK_INSTALLED_MCP=0
      shift
      ;;
    --allow-sandbox)
      ALLOW_SANDBOX=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/gemini-review-host-test.XXXXXX")"
DIRECT_OUTPUT="$TEMP_DIR/direct-output.json"
DIRECT_STDERR="$TEMP_DIR/direct-stderr.txt"
LOCAL_BRIDGE_OUTPUT="$TEMP_DIR/local-bridge-output.txt"
LOCAL_BRIDGE_STDERR="$TEMP_DIR/local-bridge-stderr.txt"
INSTALLED_MCP_JSON="$TEMP_DIR/installed-mcp.json"
INSTALLED_BRIDGE_OUTPUT="$TEMP_DIR/installed-bridge-output.txt"
INSTALLED_BRIDGE_STDERR="$TEMP_DIR/installed-bridge-stderr.txt"

[[ "$TIMEOUT_SEC" =~ ^[0-9]+$ ]] || { echo "--timeout-sec must be an integer: $TIMEOUT_SEC" >&2; exit 2; }
[[ "$MAX_RETRIES" =~ ^[0-9]+$ ]] || { echo "--max-retries must be an integer: $MAX_RETRIES" >&2; exit 2; }
RETRY_DELAY_SEC_INT="${RETRY_DELAY_SEC%%.*}"
[[ "$RETRY_DELAY_SEC_INT" =~ ^[0-9]+$ ]] || {
  echo "--retry-delay-sec must be a non-negative number: $RETRY_DELAY_SEC" >&2
  exit 2
}
OUTER_TIMEOUT_SEC=$(( (TIMEOUT_SEC + RETRY_DELAY_SEC_INT) * (MAX_RETRIES + 1) + 30 ))

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

print_proxy_keys() {
  local keys=()
  local key
  for key in http_proxy https_proxy no_proxy HTTP_PROXY HTTPS_PROXY NO_PROXY all_proxy ALL_PROXY; do
    if [[ -n "${!key-}" ]]; then
      keys+=("$key")
    fi
  done

  if (( ${#keys[@]} )); then
    printf '%s\n' "${keys[*]}"
  else
    printf '<none>\n'
  fi
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
        if isinstance(error, str) and error.strip():
            print(error.strip())
            raise SystemExit(0)
        response = payload.get("response")
        if isinstance(response, str) and response.strip():
            print(response.strip())
            raise SystemExit(0)

if "MODEL_CAPACITY_EXHAUSTED" in joined or "No capacity available" in joined:
    print("MODEL_CAPACITY_EXHAUSTED | No capacity available for requested Gemini model")
    raise SystemExit(0)
if "Manual authorization is required" in joined:
    print("AUTH_REQUIRED | run Gemini CLI login in the host environment")
    raise SystemExit(0)
if "invalid_grant" in joined or "Unauthorized" in joined:
    print("AUTH_FAILED | Gemini CLI authorization failed")
    raise SystemExit(0)
if "Auth method" in joined or "GEMINI_API_KEY" in joined:
    print("AUTH_CONFIG_MISSING | Gemini CLI did not find a configured auth method in this HOME")
    raise SystemExit(0)

message_match = re.search(r'"message"\s*:\s*"([^"]+)"', joined)
if message_match:
    print(message_match.group(1))
    raise SystemExit(0)

one_line = " ".join(joined.split())
print(one_line[:2000] + ("..." if len(one_line) > 2000 else ""))
PY
}

is_retryable_summary() {
  local summary="$1"
  case "${summary,,}" in
    *model_capacity_exhausted*|*"no capacity available"*|*resource_exhausted*|*"rate limit"*|*temporarily\ unavailable*|*deadline\ exceeded*|*timed\ out*|*timeout*|*econnreset*|*etimedout*|*"socket hang up"*)
      return 0
      ;;
  esac
  return 1
}

run_direct_cli_check() {
  echo
  echo "== 1. Direct Gemini CLI =="
  local total_attempts=$((MAX_RETRIES + 1))
  local attempt status summary
  for (( attempt = 1; attempt <= total_attempts; attempt++ )); do
    rm -f "$DIRECT_OUTPUT" "$DIRECT_STDERR"
    status=0
    if (
      cd "$TEST_CWD"
      timeout "$TIMEOUT_SEC" gemini -p "$PROMPT" \
        --output-format json \
        -m "$MODEL" >"$DIRECT_OUTPUT" 2>"$DIRECT_STDERR" < /dev/null
    ); then
      :
    else
      status=$?
    fi

    if (( status == 0 )); then
      break
    fi

    summary="$(summarize_failure "$DIRECT_OUTPUT" "$DIRECT_STDERR")"
    echo "Direct Gemini CLI attempt $attempt/$total_attempts failed with status $status: $summary" >&2
    if (( attempt < total_attempts )) && is_retryable_summary "$summary"; then
      sleep "$RETRY_DELAY_SEC"
      continue
    fi
    echo "Direct Gemini CLI check failed after $attempt attempt(s)." >&2
    exit 1
  done

  python3 - "$DIRECT_OUTPUT" "$EXPECTED" "$MODEL" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
expected = sys.argv[2]
model = sys.argv[3]
payload = json.loads(path.read_text(encoding="utf-8"))
response = str(payload.get("response", "")).strip()
if response != expected:
    raise RuntimeError(f"Unexpected Gemini direct response: expected={expected!r}, payload={payload!r}")
model_stats = payload.get("stats", {}).get("models", {}).get(model, {})
token_stats = model_stats.get("tokens", {}) if isinstance(model_stats, dict) else {}
print(json.dumps(
    {
        "response": response,
        "session_id": payload.get("session_id", ""),
        "tokens": token_stats,
        "status": "pass",
    },
    ensure_ascii=False,
    indent=2,
))
PY
}

run_local_bridge_check() {
  echo
  echo "== 2. Local gemini-review MCP bridge =="
  local status=0
  if GEMINI_REVIEW_BACKEND=cli \
    GEMINI_REVIEW_MODEL="$MODEL" \
    GEMINI_REVIEW_TIMEOUT_SEC="$TIMEOUT_SEC" \
    GEMINI_REVIEW_MAX_RETRIES="$MAX_RETRIES" \
    GEMINI_REVIEW_RETRY_DELAY_SEC="$RETRY_DELAY_SEC" \
    timeout "$OUTER_TIMEOUT_SEC" \
    python3 - "$SERVER_PATH" "$EXPECTED" "$PROMPT" "$TEST_CWD" >"$LOCAL_BRIDGE_OUTPUT" 2>"$LOCAL_BRIDGE_STDERR" <<'PY'; then
import json
import os
import subprocess
import sys

server_path = sys.argv[1]
expected = sys.argv[2]
prompt = sys.argv[3]
test_cwd = sys.argv[4]

proc = subprocess.Popen(
    [sys.executable, server_path],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True,
    env=dict(os.environ),
    cwd=test_cwd,
)

def call(payload: dict) -> dict:
    assert proc.stdin is not None
    assert proc.stdout is not None
    proc.stdin.write(json.dumps(payload) + "\n")
    proc.stdin.flush()
    line = proc.stdout.readline()
    if not line:
        stderr = proc.stderr.read().strip() if proc.stderr is not None else ""
        raise RuntimeError(f"Server returned no output. stderr={stderr}")
    return json.loads(line)

try:
    init = call({"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}})
    server_name = init.get("result", {}).get("serverInfo", {}).get("name")
    if server_name != "gemini-review":
        raise RuntimeError(f"Unexpected initialize response: {init}")

    result = call(
        {
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/call",
            "params": {"name": "review", "arguments": {"prompt": prompt}},
        }
    )
    text = result.get("result", {}).get("content", [{}])[0].get("text", "")
    payload = json.loads(text) if text else {}
    if result.get("result", {}).get("isError"):
        raise RuntimeError(json.dumps(payload, ensure_ascii=False))
    response = str(payload.get("response", "")).strip()
    if response != expected:
        raise RuntimeError(f"Unexpected bridge response: expected={expected!r}, payload={payload!r}")
    print(json.dumps({"response": response, "threadId": payload.get("threadId", ""), "model": payload.get("model", ""), "status": "pass"}, ensure_ascii=False, indent=2))
finally:
    proc.terminate()
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        proc.kill()
PY
    :
  else
    status=$?
  fi

  if (( status != 0 )); then
    echo "Local gemini-review MCP bridge check failed with status $status." >&2
    summarize_failure "$LOCAL_BRIDGE_OUTPUT" "$LOCAL_BRIDGE_STDERR" >&2
    exit 1
  fi
  cat "$LOCAL_BRIDGE_OUTPUT"
}

run_installed_mcp_check() {
  echo
  echo "== 3. Installed Codex MCP config =="
  require_command codex

  if ! codex mcp get "$MCP_NAME" --json >"$INSTALLED_MCP_JSON" 2>"$INSTALLED_BRIDGE_STDERR"; then
    echo "Installed MCP '$MCP_NAME' was not found." >&2
    echo "Install it from the host terminal first:" >&2
    echo "  bash scripts/install_codex_claude_mainline.sh --reinstall --reviewer gemini --gemini-review-model $MODEL" >&2
    exit 1
  fi

  python3 - "$INSTALLED_MCP_JSON" "$MODEL" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
expected_model = sys.argv[2]
transport = payload.get("transport", {})
env = transport.get("env", {})
proxy_keys = [key for key in ("http_proxy", "https_proxy", "no_proxy", "HTTP_PROXY", "HTTPS_PROXY", "NO_PROXY", "all_proxy", "ALL_PROXY") if env.get(key)]
summary = {
    "name": payload.get("name"),
    "enabled": payload.get("enabled"),
    "command": transport.get("command"),
    "args": transport.get("args", []),
    "GEMINI_REVIEW_BACKEND": env.get("GEMINI_REVIEW_BACKEND"),
    "GEMINI_REVIEW_MODEL": env.get("GEMINI_REVIEW_MODEL"),
    "proxy_env_keys": proxy_keys or [],
}
if payload.get("enabled") is not True:
    raise RuntimeError(f"MCP is not enabled: {summary}")
if env.get("GEMINI_REVIEW_BACKEND") != "cli":
    raise RuntimeError(f"Installed MCP does not use Gemini CLI backend: {summary}")
if env.get("GEMINI_REVIEW_MODEL") != expected_model:
    raise RuntimeError(f"Installed MCP model mismatch: expected={expected_model!r}, summary={summary!r}")
print(json.dumps(summary, ensure_ascii=False, indent=2))
PY

  echo
  echo "== 4. Installed gemini-review MCP bridge =="
  local status=0
  if timeout "$OUTER_TIMEOUT_SEC" \
    python3 - "$INSTALLED_MCP_JSON" "$EXPECTED" "$PROMPT" "$TIMEOUT_SEC" "$TEST_CWD" "$MAX_RETRIES" "$RETRY_DELAY_SEC" >"$INSTALLED_BRIDGE_OUTPUT" 2>"$INSTALLED_BRIDGE_STDERR" <<'PY'; then
import json
import os
import subprocess
import sys
from pathlib import Path

mcp_path = Path(sys.argv[1])
expected = sys.argv[2]
prompt = sys.argv[3]
timeout_sec = sys.argv[4]
test_cwd = sys.argv[5]
max_retries = sys.argv[6]
retry_delay_sec = sys.argv[7]

mcp = json.loads(mcp_path.read_text(encoding="utf-8"))
transport = mcp.get("transport", {})
command = transport.get("command")
args = transport.get("args") or []
if not command:
    raise RuntimeError(f"Installed MCP command missing: {mcp}")

env = dict(os.environ)
env.update({str(k): str(v) for k, v in (transport.get("env") or {}).items()})
env["GEMINI_REVIEW_TIMEOUT_SEC"] = str(timeout_sec)
env["GEMINI_REVIEW_MAX_RETRIES"] = str(max_retries)
env["GEMINI_REVIEW_RETRY_DELAY_SEC"] = str(retry_delay_sec)
cwd = transport.get("cwd") or test_cwd

proc = subprocess.Popen(
    [command, *args],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True,
    env=env,
    cwd=cwd,
)

def call(payload: dict) -> dict:
    assert proc.stdin is not None
    assert proc.stdout is not None
    proc.stdin.write(json.dumps(payload) + "\n")
    proc.stdin.flush()
    line = proc.stdout.readline()
    if not line:
        stderr = proc.stderr.read().strip() if proc.stderr is not None else ""
        raise RuntimeError(f"Installed MCP returned no output. stderr={stderr}")
    return json.loads(line)

try:
    init = call({"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}})
    server_name = init.get("result", {}).get("serverInfo", {}).get("name")
    if server_name != "gemini-review":
        raise RuntimeError(f"Unexpected installed initialize response: {init}")
    result = call(
        {
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/call",
            "params": {"name": "review", "arguments": {"prompt": prompt}},
        }
    )
    text = result.get("result", {}).get("content", [{}])[0].get("text", "")
    payload = json.loads(text) if text else {}
    if result.get("result", {}).get("isError"):
        raise RuntimeError(json.dumps(payload, ensure_ascii=False))
    response = str(payload.get("response", "")).strip()
    if response != expected:
        raise RuntimeError(f"Unexpected installed MCP response: expected={expected!r}, payload={payload!r}")
    print(json.dumps({"response": response, "threadId": payload.get("threadId", ""), "model": payload.get("model", ""), "status": "pass"}, ensure_ascii=False, indent=2))
finally:
    proc.terminate()
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        proc.kill()
PY
    :
  else
    status=$?
  fi

  if (( status != 0 )); then
    echo "Installed gemini-review MCP bridge check failed with status $status." >&2
    summarize_failure "$INSTALLED_BRIDGE_OUTPUT" "$INSTALLED_BRIDGE_STDERR" >&2
    exit 1
  fi
  cat "$INSTALLED_BRIDGE_OUTPUT"
}

if detect_codex_sandbox && (( ! ALLOW_SANDBOX )); then
  echo "Detected Codex/bwrap sandbox markers." >&2
  echo "Please run this script from the host terminal, not inside the current Codex tool sandbox." >&2
  echo "If you intentionally want a sandbox diagnostic, add --allow-sandbox." >&2
  exit 1
fi

require_command gemini
require_command python3
[[ -f "$SERVER_PATH" ]] || { echo "Gemini review server not found: $SERVER_PATH" >&2; exit 1; }
[[ -d "$TEST_CWD" ]] || { echo "Test working directory not found: $TEST_CWD" >&2; exit 1; }

echo "== Gemini review host test context =="
echo "repo: $REPO_ROOT"
echo "test_cwd: $TEST_CWD"
echo "launcher_cwd: $PWD"
echo "gemini_bin: $(command -v gemini)"
echo "gemini_version: $(gemini --version)"
echo "model: $MODEL"
echo "timeout_sec: $TIMEOUT_SEC"
echo "max_retries: $MAX_RETRIES"
echo "retry_delay_sec: $RETRY_DELAY_SEC"
echo "HOME: $HOME"
echo "GEMINI_CLI_HOME: ${GEMINI_CLI_HOME:-<unset>}"
echo "proxy_env_keys: $(print_proxy_keys)"
echo "expected_response: $EXPECTED"

run_direct_cli_check
run_local_bridge_check
if (( CHECK_INSTALLED_MCP )); then
  run_installed_mcp_check
fi

echo
echo "Gemini review host test passed."
