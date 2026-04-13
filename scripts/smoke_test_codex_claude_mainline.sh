#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/install_codex_claude_mainline.sh"

TEMP_HOME="$(mktemp -d "${TMPDIR:-/tmp}/aris-codex-smoke.XXXXXX")"
KEEP_TEMP=0

cleanup() {
  local status=$?
  if (( status != 0 )) || (( KEEP_TEMP != 0 )); then
    echo "Smoke test workspace preserved at: $TEMP_HOME" >&2
    return
  fi
  rm -rf "$TEMP_HOME"
}
trap cleanup EXIT

export HOME="$TEMP_HOME"
unset http_proxy https_proxy no_proxy HTTP_PROXY HTTPS_PROXY NO_PROXY all_proxy ALL_PROXY
export http_proxy="http://proxy-lower.example:8080"
export HTTPS_PROXY="http://proxy-upper.example:8443"
export no_proxy="localhost,127.0.0.1"

mkdir -p "$HOME/.codex/skills/research-review"
printf 'legacy-skill\n' > "$HOME/.codex/skills/research-review/LEGACY.txt"
mkdir -p "$HOME/.codex/mcp-servers/claude-review"
printf 'legacy-bridge\n' > "$HOME/.codex/mcp-servers/claude-review/server.py"

bash "$INSTALL_SCRIPT" --review-model smoke-model --review-fallback-model smoke-fallback-model

[[ -f "$HOME/.codex/skills/deep-innovation-loop/SKILL.md" ]]
[[ -f "$HOME/.codex/skills/paper-poster/SKILL.md" ]]
[[ -f "$HOME/.codex/skills/research-review/SKILL.md" ]]
[[ -f "$HOME/.codex/mcp-servers/claude-review/server.py" ]]
[[ -f "$HOME/.codex/.aris/codex-claude-mainline/current-manifest.json" ]]
[[ -x "$HOME/.codex/.aris/codex-claude-mainline/uninstall_codex_claude_mainline.sh" ]]

codex mcp get claude-review --json > "$HOME/claude-review-first.json"

python3 - "$HOME/claude-review-first.json" "$HOME/.codex/.aris/codex-claude-mainline/current-manifest.json" <<'PY'
import json
import sys
from pathlib import Path

mcp = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
manifest = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
env = mcp["transport"]["env"]

expected_env = {
    "http_proxy": "http://proxy-lower.example:8080",
    "HTTPS_PROXY": "http://proxy-upper.example:8443",
    "no_proxy": "localhost,127.0.0.1",
}
for key, value in expected_env.items():
    if env.get(key) != value:
        raise RuntimeError(f"Missing inherited proxy env {key}: {env}")

expected_keys = {"http_proxy", "HTTPS_PROXY", "no_proxy"}
if set(manifest.get("inherited_proxy_env_keys", [])) != expected_keys:
    raise RuntimeError(f"Unexpected inherited_proxy_env_keys: {manifest}")
if manifest.get("inherit_proxy_env") is not True:
    raise RuntimeError(f"Expected inherit_proxy_env=true: {manifest}")
PY

if bash "$INSTALL_SCRIPT" >/dev/null 2>&1; then
  echo "Expected second install without --reinstall to fail" >&2
  exit 1
fi

bash "$INSTALL_SCRIPT" --reinstall --review-model smoke-model --review-fallback-model smoke-fallback-model --no-inherit-proxy-env

codex mcp get claude-review --json > "$HOME/claude-review-second.json"

python3 - "$HOME/.codex/mcp-servers/claude-review/server.py" "$HOME/.codex/.aris/codex-claude-mainline/current-manifest.json" "$HOME/claude-review-second.json" <<'PY'
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

server_path = sys.argv[1]
manifest_path = Path(sys.argv[2])
second_mcp_path = Path(sys.argv[3])
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
if manifest.get("review_model") != "smoke-model":
    raise RuntimeError(f"Unexpected primary review model in manifest: {manifest}")
if manifest.get("review_fallback_model") != "smoke-fallback-model":
    raise RuntimeError(f"Unexpected fallback review model in manifest: {manifest}")
if manifest.get("inherit_proxy_env") is not False:
    raise RuntimeError(f"Expected inherit_proxy_env=false after opt-out reinstall: {manifest}")
if manifest.get("inherited_proxy_env_keys") != []:
    raise RuntimeError(f"Expected no inherited proxy env keys after opt-out reinstall: {manifest}")

second_mcp = json.loads(second_mcp_path.read_text(encoding="utf-8"))
second_env = second_mcp["transport"]["env"]
for forbidden_key in ("http_proxy", "HTTPS_PROXY", "no_proxy"):
    if forbidden_key in second_env:
        raise RuntimeError(f"Proxy env {forbidden_key} should not exist after opt-out reinstall: {second_env}")


def start_server(*, env: dict[str, str] | None = None) -> subprocess.Popen[str]:
    return subprocess.Popen(
        [sys.executable, server_path],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        env=env,
    )


def call(proc: subprocess.Popen[str], payload: dict) -> dict:
    assert proc.stdin is not None
    assert proc.stdout is not None
    proc.stdin.write(json.dumps(payload) + "\n")
    proc.stdin.flush()
    line = proc.stdout.readline()
    if not line:
        raise RuntimeError("Server returned no output")
    return json.loads(line)

proc = start_server()

init = call(proc, {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}})
if init.get("result", {}).get("serverInfo", {}).get("name") != "claude-review":
    raise RuntimeError(f"Unexpected initialize response: {init}")

tools = call(proc, {"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}})
tool_names = {tool["name"] for tool in tools.get("result", {}).get("tools", [])}
required = {"review_start", "review_reply_start", "review_status"}
if not required.issubset(tool_names):
    raise RuntimeError(f"Missing expected tools: {required - tool_names}")

proc.terminate()
proc.wait(timeout=5)

temp_dir = Path(tempfile.mkdtemp(prefix="claude-review-fake-"))
fake_claude = temp_dir / "claude"
fake_claude.write_text(
    """#!/usr/bin/env python3
import json
import sys

args = sys.argv[1:]
model = None
prompt = ""
for idx, arg in enumerate(args):
    if arg == "-p" and idx + 1 < len(args):
        prompt = args[idx + 1]
    if arg == "--model" and idx + 1 < len(args):
        model = args[idx + 1]

if model == "primary-model":
    print(json.dumps({"is_error": True, "error": "primary model is unavailable"}))
    raise SystemExit(1)

if model == "fallback-model":
    print(json.dumps({"result": "FAKE_FALLBACK_OK", "session_id": "fallback-thread", "model": "fallback-model", "stop_reason": "end_turn", "duration_ms": 1}))
    raise SystemExit(0)

print(json.dumps({"result": f"UNEXPECTED:{prompt}", "session_id": "unexpected-thread", "model": model or "", "stop_reason": "end_turn", "duration_ms": 1}))
""",
    encoding="utf-8",
)
fake_claude.chmod(0o755)

fake_env = dict(os.environ)
fake_env["CLAUDE_BIN"] = str(fake_claude)
fake_env["CLAUDE_REVIEW_MODEL"] = "primary-model"
fake_env["CLAUDE_REVIEW_FALLBACK_MODEL"] = "fallback-model"
fake_proc = start_server(env=fake_env)

fallback_result = call(
    fake_proc,
    {
        "jsonrpc": "2.0",
        "id": 3,
        "method": "tools/call",
        "params": {
            "name": "review",
            "arguments": {"prompt": "Reply with exactly: FALLBACK"},
        },
    },
)
fallback_payload = json.loads(fallback_result["result"]["content"][0]["text"])
if fallback_payload.get("response") != "FAKE_FALLBACK_OK":
    raise RuntimeError(f"Fallback response mismatch: {fallback_payload}")
if fallback_payload.get("model") != "fallback-model":
    raise RuntimeError(f"Fallback model mismatch: {fallback_payload}")

explicit_failure = call(
    fake_proc,
    {
        "jsonrpc": "2.0",
        "id": 4,
        "method": "tools/call",
        "params": {
            "name": "review",
            "arguments": {
                "prompt": "Reply with exactly: NO_FALLBACK",
                "model": "primary-model",
            },
        },
    },
)
if not explicit_failure.get("result", {}).get("isError"):
    raise RuntimeError(f"Explicit model call unexpectedly succeeded: {explicit_failure}")
explicit_error = json.loads(explicit_failure["result"]["content"][0]["text"])
if explicit_error.get("error") != "primary model is unavailable":
    raise RuntimeError(f"Explicit model error mismatch: {explicit_error}")

fake_proc.terminate()
fake_proc.wait(timeout=5)
PY

"$HOME/.codex/.aris/codex-claude-mainline/uninstall_codex_claude_mainline.sh"

if codex mcp get claude-review --json >/dev/null 2>&1; then
  echo "Expected claude-review MCP to be removed after uninstall" >&2
  exit 1
fi

[[ ! -e "$HOME/.codex/skills/deep-innovation-loop" ]]
[[ ! -e "$HOME/.codex/.aris/codex-claude-mainline/current-manifest.json" ]]
[[ -f "$HOME/.codex/skills/research-review/LEGACY.txt" ]]
grep -q '^legacy-bridge$' "$HOME/.codex/mcp-servers/claude-review/server.py"

echo "Smoke test passed in isolated HOME: $TEMP_HOME"
