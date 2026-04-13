#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
UNINSTALL_SCRIPT="$SCRIPT_DIR/uninstall_codex_claude_mainline.sh"

MCP_NAME="claude-review"
REVIEW_MODEL=""
USE_AWS_WRAPPER=0
REINSTALL=0

usage() {
  cat <<'EOF'
Usage: install_codex_claude_mainline.sh [options]

Options:
  --mcp-name NAME       MCP server name to register (default: claude-review)
  --review-model MODEL  Set CLAUDE_REVIEW_MODEL for the MCP server
  --use-aws-wrapper     Register run_with_claude_aws.sh instead of python3 server.py
  --reinstall           Remove the current ARIS Codex+Claude installation first
  -h, --help            Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mcp-name)
      [[ $# -ge 2 ]] || { echo "Missing value for --mcp-name" >&2; exit 1; }
      MCP_NAME="$2"
      shift 2
      ;;
    --review-model)
      [[ $# -ge 2 ]] || { echo "Missing value for --review-model" >&2; exit 1; }
      REVIEW_MODEL="$2"
      shift 2
      ;;
    --use-aws-wrapper)
      USE_AWS_WRAPPER=1
      shift
      ;;
    --reinstall)
      REINSTALL=1
      shift
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

require_command() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "Required command not found: $name" >&2
    exit 1
  fi
}

require_command codex
require_command python3

TARGET_HOME="${HOME:?HOME must be set}"
CODEX_HOME="$TARGET_HOME/.codex"
STATE_ROOT="$CODEX_HOME/.aris/codex-claude-mainline"
CURRENT_MANIFEST="$STATE_ROOT/current-manifest.json"
INSTALL_ID="$(date -u +%Y%m%dT%H%M%SZ)-$$"
WORK_ROOT="$STATE_ROOT/$INSTALL_ID"
BACKUP_ROOT="$WORK_ROOT/backup"
TOUCHED_FILE="$WORK_ROOT/touched.tsv"
LOCAL_UNINSTALL="$STATE_ROOT/uninstall_codex_claude_mainline.sh"
MCP_ADDED=0
MANIFEST_WRITTEN=0
LOCAL_UNINSTALL_WRITTEN=0

mkdir -p "$WORK_ROOT"

declare -a TOUCHED_DESTS=()
declare -a TOUCHED_BACKUPS=()

cleanup_failed_install() {
  local status=$?
  if [[ $status -eq 0 ]]; then
    return
  fi

  if (( MCP_ADDED )) && codex mcp get "$MCP_NAME" --json >/dev/null 2>&1; then
    codex mcp remove "$MCP_NAME" >/dev/null 2>&1 || true
  fi

  local i
  for (( i=${#TOUCHED_DESTS[@]}-1; i>=0; i-- )); do
    local dest="${TOUCHED_DESTS[$i]}"
    local backup_rel="${TOUCHED_BACKUPS[$i]}"

    rm -rf "$dest"
    if [[ -n "$backup_rel" ]]; then
      local backup_path="$BACKUP_ROOT/$backup_rel"
      if [[ -e "$backup_path" || -L "$backup_path" ]]; then
        mkdir -p "$(dirname "$dest")"
        cp -a "$backup_path" "$dest"
      fi
    fi
  done

  if (( MANIFEST_WRITTEN )); then
    rm -f "$CURRENT_MANIFEST"
  fi
  if (( LOCAL_UNINSTALL_WRITTEN )); then
    rm -f "$LOCAL_UNINSTALL"
  fi
  rm -rf "$WORK_ROOT"
  rmdir --ignore-fail-on-non-empty "$STATE_ROOT" 2>/dev/null || true
  rmdir --ignore-fail-on-non-empty "$CODEX_HOME/.aris" 2>/dev/null || true
}

trap cleanup_failed_install EXIT

if [[ -f "$CURRENT_MANIFEST" ]]; then
  if (( REINSTALL )); then
    bash "$UNINSTALL_SCRIPT"
  else
    echo "An ARIS Codex+Claude mainline installation already exists. Use --reinstall or uninstall first." >&2
    exit 1
  fi
fi

if codex mcp get "$MCP_NAME" --json >/dev/null 2>&1; then
  echo "An MCP server named '$MCP_NAME' already exists and is not managed by this installer." >&2
  echo "Use a different --mcp-name or remove the existing MCP server first." >&2
  exit 1
fi

backup_rel_for() {
  local dest="$1"
  local rel="${dest#"$TARGET_HOME"/}"
  if [[ "$rel" == "$dest" ]]; then
    rel="$(basename "$dest")"
  fi
  printf '%s\n' "$rel"
}

copy_exact() {
  local src="$1"
  local dest="$2"
  local backup_rel=""

  mkdir -p "$(dirname "$dest")"
  if [[ -e "$dest" || -L "$dest" ]]; then
    backup_rel="$(backup_rel_for "$dest")"
    mkdir -p "$BACKUP_ROOT/$(dirname "$backup_rel")"
    cp -a "$dest" "$BACKUP_ROOT/$backup_rel"
    rm -rf "$dest"
  fi

  cp -a "$src" "$dest"
  printf '%s\t%s\n' "$dest" "$backup_rel" >> "$TOUCHED_FILE"
  TOUCHED_DESTS+=("$dest")
  TOUCHED_BACKUPS+=("$backup_rel")
}

mkdir -p "$CODEX_HOME/skills"
while IFS= read -r -d '' src; do
  copy_exact "$src" "$CODEX_HOME/skills/$(basename "$src")"
done < <(find "$REPO_ROOT/skills/skills-codex" -mindepth 1 -maxdepth 1 -print0 | sort -z)

while IFS= read -r -d '' src; do
  copy_exact "$src" "$CODEX_HOME/skills/$(basename "$src")"
done < <(find "$REPO_ROOT/skills/skills-codex-claude-review" -mindepth 1 -maxdepth 1 -print0 | sort -z)

copy_exact "$REPO_ROOT/mcp-servers/claude-review/server.py" "$CODEX_HOME/mcp-servers/claude-review/server.py"
copy_exact "$REPO_ROOT/mcp-servers/claude-review/run_with_claude_aws.sh" "$CODEX_HOME/mcp-servers/claude-review/run_with_claude_aws.sh"
chmod +x "$CODEX_HOME/mcp-servers/claude-review/run_with_claude_aws.sh"

cmd=(codex mcp add "$MCP_NAME")
if [[ -n "$REVIEW_MODEL" ]]; then
  cmd+=(--env "CLAUDE_REVIEW_MODEL=$REVIEW_MODEL")
fi
if (( USE_AWS_WRAPPER )); then
  cmd+=(-- "$CODEX_HOME/mcp-servers/claude-review/run_with_claude_aws.sh")
else
  cmd+=(-- python3 "$CODEX_HOME/mcp-servers/claude-review/server.py")
fi
"${cmd[@]}"
MCP_ADDED=1

export INSTALL_ID
export MCP_NAME
export REVIEW_MODEL
export USE_AWS_WRAPPER
export REPO_ROOT
export BACKUP_ROOT
export TOUCHED_FILE
export CURRENT_MANIFEST

python3 - <<'PY'
import json
import os
from pathlib import Path

touched_file = Path(os.environ["TOUCHED_FILE"])
current_manifest = Path(os.environ["CURRENT_MANIFEST"])
backup_root = Path(os.environ["BACKUP_ROOT"])

touch_records = []
touched_paths = []
backed_up_paths = {}
for raw_line in touched_file.read_text(encoding="utf-8").splitlines():
    if not raw_line:
        continue
    dest, backup_rel = raw_line.split("\t", 1)
    backup_path = str(backup_root / backup_rel) if backup_rel else ""
    touch_records.append({"dest": dest, "backup_path": backup_path})
    touched_paths.append(dest)
    if backup_rel:
        backed_up_paths[dest] = backup_path

payload = {
    "install_id": os.environ["INSTALL_ID"],
    "repo_root": os.environ["REPO_ROOT"],
    "mcp_name": os.environ["MCP_NAME"],
    "wrapper_mode": "aws-wrapper" if os.environ["USE_AWS_WRAPPER"] == "1" else "direct-python",
    "review_model": os.environ["REVIEW_MODEL"],
    "backup_root": str(backup_root),
    "touch_records": touch_records,
    "touched_paths": touched_paths,
    "backed_up_paths": backed_up_paths,
}

current_manifest.parent.mkdir(parents=True, exist_ok=True)
current_manifest.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
MANIFEST_WRITTEN=1

cp -a "$UNINSTALL_SCRIPT" "$LOCAL_UNINSTALL"
LOCAL_UNINSTALL_WRITTEN=1
chmod +x "$LOCAL_UNINSTALL"

trap - EXIT

echo "Installed ARIS Codex+Claude mainline into $CODEX_HOME"
echo "Registered MCP server: $MCP_NAME"
if [[ -n "$REVIEW_MODEL" ]]; then
  echo "Pinned reviewer model: $REVIEW_MODEL"
fi
echo "Manifest: $CURRENT_MANIFEST"
echo "Uninstall helper: $LOCAL_UNINSTALL"
