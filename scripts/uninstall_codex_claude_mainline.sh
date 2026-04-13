#!/usr/bin/env bash
set -euo pipefail

TARGET_HOME="${HOME:?HOME must be set}"
CODEX_HOME="$TARGET_HOME/.codex"
STATE_ROOT="$CODEX_HOME/.aris/codex-claude-mainline"
CURRENT_MANIFEST="$STATE_ROOT/current-manifest.json"
LOCAL_UNINSTALL="$STATE_ROOT/uninstall_codex_claude_mainline.sh"

if [[ ! -f "$CURRENT_MANIFEST" ]]; then
  echo "No ARIS Codex+Claude mainline installation manifest found under $STATE_ROOT"
  exit 0
fi

require_command() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "Required command not found: $name" >&2
    exit 1
  fi
}

require_command codex
require_command python3

mapfile -t MANIFEST_LINES < <(
  python3 - "$CURRENT_MANIFEST" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
print(payload.get("mcp_name", ""))
print(payload.get("backup_root", ""))
touch_records = payload.get("touch_records")
if touch_records:
    for record in touch_records:
        print(f"{record.get('dest', '')}\t{record.get('backup_path', '')}")
else:
    for dest in payload.get("touched_paths", []):
        backup_path = payload.get("backed_up_paths", {}).get(dest, "")
        print(f"{dest}\t{backup_path}")
PY
)

if [[ ${#MANIFEST_LINES[@]} -lt 2 ]]; then
  echo "Installation manifest is malformed: $CURRENT_MANIFEST" >&2
  exit 1
fi

MCP_NAME="${MANIFEST_LINES[0]}"
BACKUP_ROOT="${MANIFEST_LINES[1]}"
TOUCHED_LINES=("${MANIFEST_LINES[@]:2}")

if [[ -n "$MCP_NAME" ]] && codex mcp get "$MCP_NAME" --json >/dev/null 2>&1; then
  codex mcp remove "$MCP_NAME"
fi

for (( i=${#TOUCHED_LINES[@]}-1; i>=0; i-- )); do
  line="${TOUCHED_LINES[$i]}"
  [[ -n "$line" ]] || continue
  IFS=$'\t' read -r dest backup_path <<<"$line"

  rm -rf "$dest"
  if [[ -n "$backup_path" ]] && [[ -e "$backup_path" || -L "$backup_path" ]]; then
    mkdir -p "$(dirname "$dest")"
    cp -a "$backup_path" "$dest"
  fi
done

rm -rf "$(dirname "$BACKUP_ROOT")"
rm -f "$CURRENT_MANIFEST"
rm -f "$LOCAL_UNINSTALL"
rmdir --ignore-fail-on-non-empty "$STATE_ROOT" 2>/dev/null || true
rmdir --ignore-fail-on-non-empty "$CODEX_HOME/.aris" 2>/dev/null || true

echo "Uninstalled ARIS Codex+Claude mainline from $CODEX_HOME"
