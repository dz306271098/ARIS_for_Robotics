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
import shutil
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
    is_compiled_execution_profile,
    is_cpu_benchmark_profile,
    is_cpu_cuda_mixed_profile,
    is_cpp_algorithm_profile,
    is_robotics_slam_profile,
    is_slam_offline_profile,
    load_autonomy_profile,
    load_cuda_profile,
    load_execution_profile,
    load_gpu_profile,
    load_robotics_profile,
    load_state,
)

profile = load_autonomy_profile(project_root)
execution = load_execution_profile(project_root)
gpu = load_gpu_profile(project_root)
cuda = load_cuda_profile(project_root)
robotics = load_robotics_profile(project_root)
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

is_cpp = is_cpp_algorithm_profile(execution)
is_robotics = is_robotics_slam_profile(execution)
is_cpu_benchmark = is_cpu_benchmark_profile(execution)
is_cpu_cuda = is_cpu_cuda_mixed_profile(execution)
is_slam_offline = is_slam_offline_profile(execution)
is_compiled = is_compiled_execution_profile(execution)
run_host = gpu.get("gpu", "").strip().lower() or "local"
build_system = execution.get("build_system", "")
benchmark_backend = execution.get("benchmark_backend", "")
artifact_roots = {item.strip() for item in execution.get("artifact_roots", "").split(",") if item.strip()}
profiling_backend = str(cuda.get("profiling_backend", "none")).strip().lower()


def require_tool(binary: str, message: str) -> None:
    if shutil.which(binary) is None:
        failures.append(message)


def require_any(binary_names: tuple[str, ...], message: str) -> None:
    if all(shutil.which(name) is None for name in binary_names):
        failures.append(message)


if execution["build_system"] == "cmake_ros2" and not is_robotics:
    failures.append("`build_system: cmake_ros2` currently requires `project_stack: robotics_slam`.")
if is_slam_offline and not is_robotics:
    failures.append("`runtime_profile: slam_offline` currently requires `project_stack: robotics_slam`.")
if is_cpu_cuda and not is_cpp:
    failures.append("`runtime_profile: cpu_cuda_mixed` currently requires `project_stack: cpp_algorithm` in unattended mode.")

if is_cpp:
    if build_system != "cmake":
        failures.append("`project_stack: cpp_algorithm` currently requires `build_system: cmake`.")
    if execution["runtime_profile"] not in {"cpu_benchmark", "cpu_cuda_mixed"}:
        failures.append("`project_stack: cpp_algorithm` currently requires `runtime_profile: cpu_benchmark` or `cpu_cuda_mixed`.")
    if execution["test_backend"] != "ctest":
        failures.append("`project_stack: cpp_algorithm` currently requires `test_backend: ctest`.")
    if benchmark_backend not in {"google_benchmark", "custom_cli"}:
        failures.append(
            "`project_stack: cpp_algorithm` requires `benchmark_backend: google_benchmark` or `custom_cli`."
        )
    if run_host not in {"local", "remote"}:
        failures.append("`project_stack: cpp_algorithm` unattended support currently requires `gpu: local` or `gpu: remote`.")

if is_robotics:
    if build_system not in {"cmake", "cmake_ros2"}:
        failures.append("`project_stack: robotics_slam` requires `build_system: cmake` or `cmake_ros2`.")
    if execution["runtime_profile"] != "slam_offline":
        failures.append("`project_stack: robotics_slam` currently requires `runtime_profile: slam_offline`.")
    if execution["test_backend"] != "ctest":
        failures.append("`project_stack: robotics_slam` currently requires `test_backend: ctest`.")
    if benchmark_backend not in {"trajectory_eval", "rosbag_eval", "custom_cli"}:
        failures.append(
            "`project_stack: robotics_slam` requires `benchmark_backend: trajectory_eval`, `rosbag_eval`, or `custom_cli`."
        )
    if run_host not in {"local", "remote"}:
        failures.append("`project_stack: robotics_slam` unattended support currently requires `gpu: local` or `gpu: remote`.")
    if robotics.get("data_backend", "") not in {"dataset", "rosbag", "simulator"}:
        failures.append("`Robotics Profile -> data_backend` must be `dataset`, `rosbag`, or `simulator`.")
    if build_system == "cmake_ros2":
        require_tool("colcon", "ROS2 robotics mode requires `colcon` on the host.")
        require_tool("ros2", "ROS2 robotics mode requires `ros2` on the host.")

if is_compiled:
    require_tool("cmake", "Compiled execution mode requires `cmake` on the host.")
    require_tool("ctest", "Compiled execution mode requires `ctest` on the host.")
    require_any(("c++", "g++", "clang++"), "Compiled execution mode requires a C++ compiler (`c++`, `g++`, or `clang++`).")
    require_any(("ninja", "make"), "Compiled execution mode requires at least one build tool: `ninja` or `make`.")

if is_cpu_benchmark:
    for required_root in {"build", "results", "monitoring"}:
        if required_root not in artifact_roots:
            failures.append("`runtime_profile: cpu_benchmark` should include `build,results,monitoring` in `artifact_roots`.")
            break

if is_cpu_cuda:
    if not bool(cuda.get("cuda_enabled")):
        failures.append("`runtime_profile: cpu_cuda_mixed` requires `CUDA Profile -> cuda_enabled: true`.")
    require_tool("nvcc", "CMake CUDA mode requires `nvcc` on the host.")
    require_tool("nvidia-smi", "CMake CUDA mode requires `nvidia-smi` on the host.")
    if profiling_backend not in {"none", "perf", "nsys", "ncu"}:
        failures.append("`CUDA Profile -> profiling_backend` must be `none`, `perf`, `nsys`, or `ncu`.")
    if profiling_backend == "perf":
        require_tool("perf", "`profiling_backend: perf` requires `perf` on the host.")
    if profiling_backend == "nsys":
        require_tool("nsys", "`profiling_backend: nsys` requires `nsys` on the host.")
    if profiling_backend == "ncu":
        require_tool("ncu", "`profiling_backend: ncu` requires `ncu` on the host.")
    for required_root in {"build", "results", "monitoring", "profiles"}:
        if required_root not in artifact_roots:
            failures.append("`runtime_profile: cpu_cuda_mixed` should include `build,results,monitoring,profiles` in `artifact_roots`.")
            break
    notes.append("cpu_cuda_mixed execution profile detected: passing tests gate benchmarks; CUDA profiler artifacts become first-class evidence.")

if is_slam_offline:
    for required_root in {"build", "results", "monitoring"}:
        if required_root not in artifact_roots:
            failures.append("`runtime_profile: slam_offline` should include `build,results,monitoring` in `artifact_roots`.")
            break
    notes.append("slam_offline execution profile detected: only offline / simulator / rosbag evidence is in scope; real-robot automation stays blocked.")

if profile["allow_auto_cloud"] is False and run_host == "vast":
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
        notes.append("watchdog not running yet (acceptable before training or long benchmark starts).")

if profile["require_wandb_for_unattended_training"] and execution["runtime_profile"] == "training":
    wandb_enabled = any(line.strip().lower() == "- wandb: true" for line in codex_text.splitlines())
    wandb_project = "wandb_project:" in codex_text
    if not wandb_enabled or not wandb_project:
        failures.append("Unattended training requires `wandb: true` and `wandb_project:` in CODEX.md.")
elif execution["runtime_profile"] in {"cpu_benchmark", "cpu_cuda_mixed", "slam_offline"}:
    notes.append(f"{execution['runtime_profile']} execution profile detected: W&B is treated as optional.")

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
    "execution_profile": execution,
    "cuda_profile": cuda,
    "robotics_profile": robotics,
    "gpu_profile": gpu,
    "state_path": str(state_path),
    "notes": notes,
    "failures": failures,
}
print(json.dumps(summary, ensure_ascii=False, indent=2))
if failures:
    raise SystemExit(1)
PY2
