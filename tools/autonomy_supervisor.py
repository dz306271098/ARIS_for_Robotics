#!/usr/bin/env python3
"""Supervisor for unattended core-mainline ARIS runs."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

from autonomy_lib import (
    allow_vast_reuse_without_provision,
    autonomy_state_path,
    is_compiled_execution_profile,
    is_cpu_benchmark_profile,
    is_cpu_cuda_mixed_profile,
    is_robotics_slam_profile,
    is_slam_offline_profile,
    load_autonomy_profile,
    load_execution_profile,
    load_gpu_profile,
    load_state,
    now_iso,
    parse_iso8601,
)

VALID_WORKFLOWS = {
    "research-pipeline",
    "experiment-bridge",
    "deep-innovation-loop",
    "auto-review-loop",
    "paper-writing",
}
ACTIVE_STATUSES = {"in_progress", "blocked"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run ARIS core-mainline workflows in unattended-safe mode.")
    parser.add_argument("--project-root", default=".", help="Project root containing CODEX.md")
    parser.add_argument("--workflow", default="research-pipeline", choices=sorted(VALID_WORKFLOWS))
    parser.add_argument("--topic", help="Topic or free-form arguments for the workflow")
    parser.add_argument("--paper-input", help="Narrative report or paper plan path for /paper-writing")
    parser.add_argument("--resume", action="store_true", help="Resume from AUTONOMY_STATE.json if possible")
    parser.add_argument("--skip-health-check", action="store_true", help="Skip scripts/check_unattended_mainline.sh")
    parser.add_argument("--dry-run", action="store_true", help="Write state + print the generated Codex prompt without executing it.")
    parser.add_argument("--codex-bin", default="codex")
    return parser.parse_args()


def ensure_profile(project_root: Path) -> dict[str, object]:
    profile = load_autonomy_profile(project_root)
    if profile["autonomy_mode"] != "unattended_safe":
        raise RuntimeError(
            "CODEX.md must set `autonomy_mode: unattended_safe` in `## Autonomy Profile` before using the unattended supervisor."
        )
    if profile["automation_scope"] != "core_mainline":
        raise RuntimeError("The unattended supervisor only supports `automation_scope: core_mainline`.")
    if profile["priority"] != "quality_stability":
        raise RuntimeError("The unattended supervisor only supports `priority: quality_stability`.")
    return profile


def build_workflow_args(args: argparse.Namespace, workflow: str) -> str:
    if workflow == "paper-writing":
        return args.paper_input or args.topic or "NARRATIVE_REPORT.md"
    return args.topic or ""


def build_prompt(workflow: str, workflow_args: str, execution_profile: dict[str, str]) -> str:
    arg_literal = workflow_args.replace('"', '\"')
    lines = [
        f'Run the `/{workflow}` skill for this project with arguments "{arg_literal}".',
        "",
        "Non-negotiable unattended-safe policy:",
        "- Read CODEX.md, especially `## Execution Profile`, `## CUDA Profile`, `## Robotics Profile`, and `## Autonomy Profile`, and obey them as the project contract.",
        "- Use `python3 tools/update_autonomy_state.py` to update AUTONOMY_STATE.json at each major phase transition, heartbeat, blocker, and completion.",
        "- Do not ask for human confirmation unless a hard safety boundary from the autonomy profile forces a stop.",
        "- Treat missing reviewer runtime, missing required W&B logging for unattended long runs, or forbidden cloud auto-provisioning as blocking conditions and record the blocker explicitly.",
        "- Run every external model call through a host-first runtime (`external_model_runtime: host_first`): use host MCP bridges or host-side helper scripts, not direct `claude`, `gemini`, MiniMax, or Gemini API calls from the Codex sandbox.",
        "- If an external model backend fails and `external_model_failure_policy: retry_then_local_fallback`, a provisional local critic or placeholder artifact may keep intermediate work moving, but set `external_model_replay_required=true` and preserve the recovery step.",
        "- Use the autonomy-profile reviewer fallback policy: retry reviewer runtime first; if `review_fallback_mode` is `retry_then_local_critic`, a provisional local-critic pass is allowed only for intermediate progress and must set `review_mode=local_fallback` plus `review_replay_required=true` in AUTONOMY_STATE.json.",
        "- Never mark claim-freeze, final paper-polish, rebuttal, or required AI-generated figures as fully completed while `review_replay_required=true` or `external_model_replay_required=true`.",
        "- Reuse existing workflow recovery files if they exist; do not restart completed work from scratch.",
    ]

    if is_compiled_execution_profile(execution_profile):
        lines.extend([
            "- This project is using a compiled execution path: treat passing tests as a hard gate before benchmark runs, CUDA profiling sweeps, or offline SLAM replay.",
            "- For non-training execution profiles, W&B is optional; rely on build logs, CTest results, benchmark summaries, trajectory/perception summaries, and profiler artifacts instead.",
            "- Prefer `/dse-loop` and `/system-profile` as sidecars when the experiment plan calls for sweeps, CUDA hotspot diagnosis, or systems bottleneck analysis.",
        ])

    if is_cpu_benchmark_profile(execution_profile):
        lines.append("- `runtime_profile: cpu_benchmark` should follow `cmake configure -> build -> ctest -> benchmark`, with machine-readable benchmark outputs.")

    if is_cpu_cuda_mixed_profile(execution_profile):
        lines.extend([
            "- `runtime_profile: cpu_cuda_mixed` must keep nvcc/CMake CUDA, benchmark artifacts, and GPU profiling summaries (`perf`, `nsys`, or `ncu`) aligned with the experiment plan.",
            "- Do not claim CUDA speedups without test-passing correctness and explicit evidence for kernel time, transfer cost, and throughput/overlap behavior.",
        ])

    if is_robotics_slam_profile(execution_profile) or is_slam_offline_profile(execution_profile):
        lines.extend([
            "- `project_stack: robotics_slam` / `runtime_profile: slam_offline` means offline dataset / rosbag / simulator execution only; never attempt autonomous real-robot runs.",
            "- Use plain CMake by default; if `build_system: cmake_ros2`, treat ROS2 as an adapter (`colcon build`, `ros2 run` / launch) while keeping the same offline-only safety boundary.",
            "- Do not let offline / simulator / rosbag evidence expand into real-robot claims; trajectory, perception, latency, and drift summaries must stay within offline scope.",
        ])

    return "\n".join(lines) + "\n"

def run_health_check(repo_root: Path, project_root: Path, workflow: str) -> None:
    cmd = [
        "bash",
        str(repo_root / "scripts" / "check_unattended_mainline.sh"),
        "--target-skill",
        workflow,
        str(project_root),
    ]
    subprocess.run(cmd, check=True)


def run_codex(codex_bin: str, project_root: Path, prompt: str, log_path: Path) -> int:
    cmd = [
        codex_bin,
        "exec",
        "--dangerously-bypass-approvals-and-sandbox",
        "-C",
        str(project_root),
        prompt,
    ]
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("w", encoding="utf-8") as handle:
        process = subprocess.run(cmd, stdout=handle, stderr=subprocess.STDOUT, text=True)
    return process.returncode


def lock_path(project_root: Path) -> Path:
    return project_root / ".aris" / "autonomy" / "supervisor.lock"


def write_state(
    repo_root: Path,
    project_root: Path,
    *,
    workflow: str,
    phase: str,
    status: str,
    next_skill: str,
    next_args: str,
    blocking_reason: str,
    retry_count: int | None = None,
    review_mode: str | None = None,
    review_replay_required: bool | None = None,
    external_model_replay_required: bool | None = None,
    recovery_step: str | None = None,
    note: str = "",
) -> None:
    cmd = [
        sys.executable,
        str(repo_root / "tools" / "update_autonomy_state.py"),
        "--project-root",
        str(project_root),
        "--workflow",
        workflow,
        "--phase",
        phase,
        "--status",
        status,
        "--next-skill",
        next_skill,
        "--next-args",
        next_args,
        "--blocking-reason",
        blocking_reason,
        "--note",
        note,
        "--touch-heartbeat",
    ]
    if retry_count is not None:
        cmd.extend(["--retry-count", str(retry_count)])
    if review_mode is not None:
        cmd.extend(["--review-mode", review_mode])
    if review_replay_required is not None:
        cmd.extend(["--review-replay-required", str(review_replay_required).lower()])
    if external_model_replay_required is not None:
        cmd.extend(["--external-model-replay-required", str(external_model_replay_required).lower()])
    if recovery_step is not None:
        cmd.extend(["--recovery-step", recovery_step])
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL)


def acquire_lock(path: Path, workflow: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            payload = {}
        pid = int(payload.get("pid", 0) or 0)
        if pid > 0:
            try:
                os.kill(pid, 0)
            except OSError:
                pass
            else:
                raise RuntimeError(
                    f"Another unattended supervisor is already active for this project (pid={pid}, workflow={payload.get('workflow', '')})."
                )
    payload = {
        "pid": os.getpid(),
        "workflow": workflow,
        "acquired_at": now_iso(),
    }
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def release_lock(path: Path) -> None:
    if not path.exists():
        return
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        payload = {}
    if int(payload.get("pid", 0) or 0) == os.getpid():
        path.unlink(missing_ok=True)


def can_resume_within_window(state: dict[str, object], resume_window_hours: int) -> bool:
    status = str(state.get("status", "")).strip().lower()
    if status not in ACTIVE_STATUSES:
        return False
    updated_at = parse_iso8601(str(state.get("updated_at", "")))
    if updated_at is None:
        return False
    now = parse_iso8601(now_iso())
    if now is None:
        return False
    age_seconds = (now - updated_at).total_seconds()
    return age_seconds <= resume_window_hours * 3600


def main() -> int:
    args = parse_args()
    repo_root = Path(__file__).resolve().parents[1]
    project_root = Path(args.project_root).resolve()
    state_path = autonomy_state_path(project_root)
    profile = ensure_profile(project_root)
    execution_profile = load_execution_profile(project_root)
    gpu_profile = load_gpu_profile(project_root)

    workflow = args.workflow
    workflow_args = build_workflow_args(args, workflow)
    state = load_state(state_path) if state_path.exists() else {}

    if args.resume and state_path.exists() and can_resume_within_window(state, int(profile["resume_window_hours"])):
        if state.get("next_skill") in VALID_WORKFLOWS:
            workflow = str(state["next_skill"])
            workflow_args = str(state.get("next_args", workflow_args))

    retry_count = int(state.get("retry_count", 0) or 0)
    current_review_mode = str(state.get("review_mode", "external") or "external")
    current_review_replay_required = bool(state.get("review_replay_required", False))
    current_external_model_replay_required = bool(state.get("external_model_replay_required", False))

    if profile["allow_auto_cloud"] is False and gpu_profile.get("gpu", "").strip().lower() == "vast":
        if not allow_vast_reuse_without_provision(project_root):
            write_state(
                repo_root,
                project_root,
                workflow=workflow,
                phase="supervisor_preflight_failed",
                status="blocked",
                next_skill=workflow,
                next_args=workflow_args,
                blocking_reason="missing_running_vast_instance",
                review_mode=current_review_mode,
                review_replay_required=current_review_replay_required,
                external_model_replay_required=current_external_model_replay_required,
                recovery_step="preflight_vast_blocked",
                note="allow_auto_cloud is false and no reusable vast.ai instance was found",
            )
            raise RuntimeError(
                "This project is configured with `gpu: vast`, but unattended-safe mode forbids automatic cloud provisioning and no running instance was found in `vast-instances.json`."
            )
    if retry_count >= int(profile["max_auto_retries_per_stage"]):
        raise RuntimeError("Maximum unattended retries reached for the current stage. Inspect AUTONOMY_STATE.json before retrying.")

    prompt = build_prompt(workflow, workflow_args, execution_profile)
    supervisor_lock = lock_path(project_root)
    acquire_lock(supervisor_lock, workflow)
    try:
        write_state(
            repo_root,
            project_root,
            workflow=workflow,
            phase="supervisor_dispatch",
            status="in_progress",
            next_skill=workflow,
            next_args=workflow_args,
            blocking_reason="",
            retry_count=retry_count,
            review_mode=current_review_mode,
            review_replay_required=current_review_replay_required,
            external_model_replay_required=current_external_model_replay_required,
            recovery_step="supervisor_dispatch",
            note="Supervisor dispatch",
        )

        if args.dry_run:
            payload = {
                "workflow": workflow,
                "workflow_args": workflow_args,
                "project_root": str(project_root),
                "generated_at": now_iso(),
                "execution_profile": execution_profile,
                "prompt": prompt,
            }
            print(json.dumps(payload, indent=2, ensure_ascii=False))
            return 0

        if not args.skip_health_check:
            try:
                run_health_check(repo_root, project_root, workflow)
            except subprocess.CalledProcessError as exc:
                write_state(
                    repo_root,
                    project_root,
                    workflow=workflow,
                    phase="supervisor_preflight_failed",
                    status="blocked",
                    next_skill=workflow,
                    next_args=workflow_args,
                    blocking_reason=f"preflight_exit_{exc.returncode}",
                    review_mode=current_review_mode,
                    review_replay_required=current_review_replay_required,
                    external_model_replay_required=current_external_model_replay_required,
                    recovery_step="supervisor_preflight_failed",
                    note="Unattended health check failed",
                )
                raise

        log_path = project_root / ".aris" / "autonomy" / "last_supervisor_run.log"
        return_code = run_codex(args.codex_bin, project_root, prompt, log_path)

        if return_code == 0:
            write_state(
                repo_root,
                project_root,
                workflow=workflow,
                phase="supervisor_complete",
                status="completed",
                next_skill="",
                next_args="",
                blocking_reason="",
                review_mode="external",
                review_replay_required=False,
                external_model_replay_required=False,
                recovery_step="supervisor_complete",
                note=f"Completed successfully. Log: {log_path}",
            )
            return 0

        retry_count += 1
        write_state(
            repo_root,
            project_root,
            workflow=workflow,
            phase="supervisor_failed",
            status="blocked",
            next_skill=workflow,
            next_args=workflow_args,
            blocking_reason=f"codex_exec_exit_{return_code}",
            retry_count=retry_count,
            review_mode=current_review_mode,
            review_replay_required=current_review_replay_required,
            external_model_replay_required=current_external_model_replay_required,
            recovery_step="supervisor_failed",
            note=f"Codex exec failed. Inspect {log_path}",
        )
        return return_code
    finally:
        release_lock(supervisor_lock)


if __name__ == "__main__":
    raise SystemExit(main())
