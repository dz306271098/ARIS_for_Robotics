#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SKIP_REVIEWER_CHECK=0
TARGET_SKILL=""
PROJECT_ROOT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-reviewer-check)
      SKIP_REVIEWER_CHECK=1
      shift
      ;;
    --target-skill)
      TARGET_SKILL="${2:-}"
      shift 2
      ;;
    -*)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
    *)
      PROJECT_ROOT="$1"
      shift
      ;;
  esac
done

PROJECT_ROOT="${PROJECT_ROOT:-$PWD}"
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

if [[ ! -f "$PROJECT_ROOT/CODEX.md" ]]; then
  echo "Missing CODEX.md in project root: $PROJECT_ROOT" >&2
  exit 1
fi

if (( SKIP_REVIEWER_CHECK == 0 )); then
  bash "$REPO_ROOT/scripts/check_claude_review_runtime.sh"
fi

python3 - "$REPO_ROOT" "$PROJECT_ROOT" "$TARGET_SKILL" <<'PY2'
import json
import os
import sys
from pathlib import Path

repo_root = Path(sys.argv[1])
project_root = Path(sys.argv[2])
target_skill = sys.argv[3]
sys.path.insert(0, str(repo_root / "tools"))

from autonomy_lib import (
    allow_vast_reuse_without_provision,
    autonomy_state_path,
    find_running_vast_instance,
    load_autonomy_profile,
    load_gpu_profile,
    load_state,
)

profile = load_autonomy_profile(project_root)
gpu = load_gpu_profile(project_root)
state_path = autonomy_state_path(project_root)
state = load_state(state_path) if state_path.exists() else {}
codex_text = (project_root / "CODEX.md").read_text(encoding="utf-8")

failures = []
notes = []

if profile["autonomy_mode"] != "unattended_safe":
    failures.append("CODEX.md -> ## Autonomy Profile must set `autonomy_mode: unattended_safe`.")
if profile["automation_scope"] != "core_mainline":
    failures.append("Unattended mode only supports `automation_scope: core_mainline`.")
if profile["priority"] != "quality_stability":
    failures.append("Unattended mode only supports `priority: quality_stability`.")

review_fallback_mode = str(profile.get("review_fallback_mode", "retry_then_local_critic")).strip().lower()
if review_fallback_mode not in {"retry_then_block", "retry_then_local_critic"}:
    failures.append("`review_fallback_mode` must be `retry_then_block` or `retry_then_local_critic`.")

max_reviewer_runtime_retries = int(profile.get("max_reviewer_runtime_retries", 2) or 0)
if max_reviewer_runtime_retries < 1:
    failures.append("`max_reviewer_runtime_retries` must be >= 1.")

if profile["allow_auto_cloud"] is False and gpu.get("gpu", "").strip().lower() == "vast":
    running_instance = find_running_vast_instance(project_root)
    if running_instance:
        notes.append(
            "reusing running vast instance: "
            f"instance_id={running_instance.get('instance_id')} status={running_instance.get('status')}"
        )
    elif allow_vast_reuse_without_provision(project_root):
        notes.append("vast reuse allowed via existing running instance metadata")
    else:
        failures.append(
            "`allow_auto_cloud: false` requires an already-running vast.ai instance in `vast-instances.json`; none was found."
        )

if profile["require_watchdog"]:
    watchdog_path = repo_root / "tools" / "watchdog.py"
    if not watchdog_path.exists():
        failures.append("`require_watchdog: true` but tools/watchdog.py is missing.")
    pid_file = Path("/tmp/aris-watchdog/watchdog.pid")
    if pid_file.exists():
        try:
            pid = int(pid_file.read_text(encoding="utf-8").strip())
            os.kill(pid, 0)
            notes.append(f"watchdog running: pid={pid}")
        except Exception:
            failures.append("watchdog.pid exists but the process is not alive.")
    else:
        notes.append("watchdog not running yet (acceptable before training starts).")

if profile["require_wandb_for_unattended_training"]:
    wandb_enabled = any(line.strip().lower() == "- wandb: true" for line in codex_text.splitlines())
    wandb_project = "wandb_project:" in codex_text
    if not wandb_enabled or not wandb_project:
        failures.append("Unattended training requires `wandb: true` and `wandb_project:` in CODEX.md.")

check_paper_backend = target_skill == "paper-writing" or state.get("next_skill") == "paper-writing"
if check_paper_backend and str(profile["paper_illustration"]).strip().lower() == "auto":
    if not os.environ.get("GEMINI_API_KEY"):
        failures.append("paper-writing unattended mode requires GEMINI_API_KEY when `paper_illustration: auto`.")

if state_path.exists():
    required_keys = {
        "workflow",
        "phase",
        "status",
        "next_skill",
        "next_args",
        "blocking_reason",
        "retry_count",
        "last_heartbeat",
        "started_at",
        "updated_at",
    }
    missing = sorted(required_keys - set(state))
    if missing:
        failures.append(f"AUTONOMY_STATE.json is missing keys: {', '.join(missing)}")
else:
    notes.append("AUTONOMY_STATE.json not present yet (acceptable before the first unattended run).")

summary = {
    "project_root": str(project_root),
    "target_skill": target_skill or state.get("next_skill", ""),
    "review_fallback_mode": review_fallback_mode,
    "max_reviewer_runtime_retries": max_reviewer_runtime_retries,
    "autonomy_profile": profile,
    "gpu_profile": gpu,
    "state_path": str(state_path),
    "notes": notes,
    "failures": failures,
}
print(json.dumps(summary, ensure_ascii=False, indent=2))
if failures:
    raise SystemExit(1)
PY2
