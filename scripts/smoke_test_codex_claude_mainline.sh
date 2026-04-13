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

mkdir -p "$HOME/.codex/skills/research-review"
printf 'legacy-skill\n' > "$HOME/.codex/skills/research-review/LEGACY.txt"
mkdir -p "$HOME/.codex/mcp-servers/claude-review"
printf 'legacy-bridge\n' > "$HOME/.codex/mcp-servers/claude-review/server.py"

bash "$INSTALL_SCRIPT" --review-model smoke-model

[[ -f "$HOME/.codex/skills/deep-innovation-loop/SKILL.md" ]]
[[ -f "$HOME/.codex/skills/paper-poster/SKILL.md" ]]
[[ -f "$HOME/.codex/skills/research-review/SKILL.md" ]]
[[ -f "$HOME/.codex/mcp-servers/claude-review/server.py" ]]
[[ -f "$HOME/.codex/.aris/codex-claude-mainline/current-manifest.json" ]]
[[ -x "$HOME/.codex/.aris/codex-claude-mainline/uninstall_codex_claude_mainline.sh" ]]

codex mcp get claude-review --json >/dev/null

if bash "$INSTALL_SCRIPT" >/dev/null 2>&1; then
  echo "Expected second install without --reinstall to fail" >&2
  exit 1
fi

bash "$INSTALL_SCRIPT" --reinstall --review-model smoke-model

python3 - "$HOME/.codex/mcp-servers/claude-review/server.py" <<'PY'
import json
import subprocess
import sys

server_path = sys.argv[1]
proc = subprocess.Popen(
    [sys.executable, server_path],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True,
)

def call(payload: dict) -> dict:
    assert proc.stdin is not None
    assert proc.stdout is not None
    proc.stdin.write(json.dumps(payload) + "\n")
    proc.stdin.flush()
    line = proc.stdout.readline()
    if not line:
        raise RuntimeError("Server returned no output")
    return json.loads(line)

init = call({"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}})
if init.get("result", {}).get("serverInfo", {}).get("name") != "claude-review":
    raise RuntimeError(f"Unexpected initialize response: {init}")

tools = call({"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}})
tool_names = {tool["name"] for tool in tools.get("result", {}).get("tools", [])}
required = {"review_start", "review_reply_start", "review_status"}
if not required.issubset(tool_names):
    raise RuntimeError(f"Missing expected tools: {required - tool_names}")

proc.terminate()
proc.wait(timeout=5)
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
