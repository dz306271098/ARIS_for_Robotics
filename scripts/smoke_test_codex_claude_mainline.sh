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
[[ -f "$SCRIPT_DIR/../templates/CODEX_TEMPLATE.md" ]]
[[ -f "$SCRIPT_DIR/../tools/autonomy_supervisor.py" ]]
[[ -f "$SCRIPT_DIR/../skills/skills-codex/shared-references/unattended-runtime-protocol.md" ]]

SMOKE_PROJECT="$HOME/unattended-project"
mkdir -p "$SMOKE_PROJECT"
cp "$SCRIPT_DIR/../templates/CODEX_TEMPLATE.md" "$SMOKE_PROJECT/CODEX.md"

bash "$SCRIPT_DIR/check_unattended_mainline.sh" --skip-reviewer-check "$SMOKE_PROJECT"
python3 "$SCRIPT_DIR/../tools/update_autonomy_state.py" \
  --project-root "$SMOKE_PROJECT" \
  --workflow research-pipeline \
  --phase init \
  --status in_progress \
  --next-skill research-pipeline \
  --next-args "smoke topic" \
  --blocking-reason "" \
  --retry-count 0 \
  --review-mode external \
  --review-replay-required false \
  --recovery-step init \
  --touch-heartbeat >/dev/null
python3 "$SCRIPT_DIR/../tools/autonomy_supervisor.py" \
  --project-root "$SMOKE_PROJECT" \
  --workflow research-pipeline \
  --topic "smoke topic" \
  --skip-health-check \
  --dry-run > "$HOME/autonomy-supervisor.json"
python3 - "$HOME/autonomy-supervisor.json" "$SMOKE_PROJECT/AUTONOMY_STATE.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
state = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
if payload.get("workflow") != "research-pipeline":
    raise RuntimeError(payload)
if "Autonomy Profile" not in payload.get("prompt", ""):
    raise RuntimeError(payload)
if "review_replay_required=true" not in payload.get("prompt", ""):
    raise RuntimeError(payload)
required = {"workflow", "phase", "status", "next_skill", "next_args", "blocking_reason", "retry_count", "last_heartbeat", "started_at", "updated_at", "review_mode", "review_replay_required", "recovery_step"}
missing = sorted(required - set(state))
if missing:
    raise RuntimeError(f"missing state keys: {missing}")
if state["review_replay_required"] is not False:
    raise RuntimeError(state)
PY

python3 - "$SMOKE_PROJECT/AUTONOMY_STATE.json" <<'PY'
import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

path = Path(sys.argv[1])
state = json.loads(path.read_text(encoding="utf-8"))
now = datetime.now(timezone.utc)
state.update(
    {
        "status": "in_progress",
        "next_skill": "auto-review-loop",
        "next_args": "resume topic",
        "phase": "resume_candidate",
        "review_mode": "local_fallback",
        "review_replay_required": True,
        "recovery_step": "waiting_for_reviewer_replay",
        "updated_at": now.isoformat().replace("+00:00", "Z"),
        "last_heartbeat": now.isoformat().replace("+00:00", "Z"),
    }
)
path.write_text(json.dumps(state, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
PY
python3 "$SCRIPT_DIR/../tools/autonomy_supervisor.py" \
  --project-root "$SMOKE_PROJECT" \
  --workflow research-pipeline \
  --topic "fresh topic" \
  --resume \
  --skip-health-check \
  --dry-run > "$HOME/autonomy-supervisor-resume.json"
python3 - "$HOME/autonomy-supervisor-resume.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload.get("workflow") != "auto-review-loop":
    raise RuntimeError(payload)
if payload.get("workflow_args") != "resume topic":
    raise RuntimeError(payload)
PY

python3 - "$SMOKE_PROJECT/AUTONOMY_STATE.json" <<'PY'
import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

path = Path(sys.argv[1])
state = json.loads(path.read_text(encoding="utf-8"))
stale = datetime.now(timezone.utc) - timedelta(hours=30)
state.update(
    {
        "updated_at": stale.isoformat().replace("+00:00", "Z"),
        "last_heartbeat": stale.isoformat().replace("+00:00", "Z"),
    }
)
path.write_text(json.dumps(state, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
PY
python3 "$SCRIPT_DIR/../tools/autonomy_supervisor.py" \
  --project-root "$SMOKE_PROJECT" \
  --workflow research-pipeline \
  --topic "fresh topic" \
  --resume \
  --skip-health-check \
  --dry-run > "$HOME/autonomy-supervisor-stale.json"
python3 - "$HOME/autonomy-supervisor-stale.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload.get("workflow") != "research-pipeline":
    raise RuntimeError(payload)
if payload.get("workflow_args") != "fresh topic":
    raise RuntimeError(payload)
PY

EVAL_EMPTY="$HOME/eval-empty-project"
mkdir -p "$EVAL_EMPTY"
bash "$SCRIPT_DIR/eval_research_workflow.sh" "$EVAL_EMPTY" > "$HOME/eval-empty.json"
python3 - "$HOME/eval-empty.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if not any(task["missing_artifacts"] for task in payload.get("tasks", [])):
    raise RuntimeError(payload)
PY

EVAL_FULL="$HOME/eval-full-project"
mkdir -p "$EVAL_FULL"
python3 - "$EVAL_FULL" <<'PY'
import sys
from pathlib import Path

project = Path(sys.argv[1])
artifacts = {
    "IDEA_PORTFOLIO.md": "# Novelty\nsafe bold contrarian novelty\n",
    "IDEA_REPORT.md": "# Idea Report\ncross-domain analog\n",
    "CLAIMS_FROM_RESULTS.md": "# Claims\nfailure principle revive wrong assumption\n",
    "literature-logs/PRINCIPLE_BANK.md": "# Distilled principle\npreconditions\n",
    "literature-logs/ANALOGY_CANDIDATES.md": "# Analog candidates\ncross-domain analog\n",
    "refine-logs/ROUTE_PORTFOLIO.md": "# Routes\nbranch-kill\n",
    "refine-logs/PLAN_DECISIONS.md": "# Plan decisions\ndisconfirming\n",
    "research-wiki/failure_pack.md": "# Failure pack\nfailure principle revive wrong assumption\n",
    "research-wiki/principle_pack.md": "# Principle pack\nclosest prior novelty\n",
    "LITERATURE_MAP.md": "# Literature map\n",
    "NOVELTY_SURFACE.md": "# Novelty surface\nclosest prior novelty\n",
}
for relative_path, contents in artifacts.items():
    target = project / relative_path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(contents, encoding="utf-8")
PY
bash "$SCRIPT_DIR/eval_research_workflow.sh" "$EVAL_FULL" > "$HOME/eval-full.json"
python3 - "$HOME/eval-full.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if not all(task["passed_artifacts"] for task in payload.get("tasks", [])):
    raise RuntimeError(payload)
if payload["dimensions"]["literature_coverage"]["score"] < 3:
    raise RuntimeError(payload)
PY

CPP_PROJECT="$HOME/cpp-algorithm-project"
mkdir -p "$CPP_PROJECT"
cp -a "$SCRIPT_DIR/../fixtures/cpp_algorithm_project/." "$CPP_PROJECT/"

bash "$SCRIPT_DIR/check_unattended_mainline.sh" --skip-reviewer-check "$CPP_PROJECT"
cmake -S "$CPP_PROJECT" -B "$CPP_PROJECT/build" -DCMAKE_BUILD_TYPE=Release
cmake --build "$CPP_PROJECT/build" -- -j2
(cd "$CPP_PROJECT/build" && ctest --output-on-failure)
mkdir -p "$CPP_PROJECT/results" "$CPP_PROJECT/monitoring"
"$CPP_PROJECT/build/bin/vector_stats_benchmark" --output "$CPP_PROJECT/results/vector_stats_raw.json"

python3 - "$CPP_PROJECT" <<'PY'
import json
import sys
from pathlib import Path

project = Path(sys.argv[1])
build_dir = project / "build"
results_dir = project / "results"
monitoring_dir = project / "monitoring"
raw = json.loads((results_dir / "vector_stats_raw.json").read_text(encoding="utf-8"))
if raw.get("benchmark") != "vector_stats_benchmark":
    raise RuntimeError(raw)
if len(raw.get("cases", [])) != 3:
    raise RuntimeError(raw)
for case in raw["cases"]:
    if case["mean_ns"] <= 0 or case["items_per_second"] <= 0:
        raise RuntimeError(case)

build_report = {
    "configure_status": "configured",
    "build_status": "built",
    "test_status": "passed",
    "build_dir": str(build_dir),
}
(build_dir / "build_report.json").write_text(json.dumps(build_report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

manifest = {
    "project_stack": "cpp_algorithm",
    "build_system": "cmake",
    "runtime_profile": "cpu_benchmark",
    "benchmarks": [
        {
            "target": "vector_stats_benchmark",
            "binary": str(build_dir / "bin" / "vector_stats_benchmark"),
            "timeout_seconds": 60,
            "repeat_count": raw["repeat"],
            "parser_type": "custom_json",
            "baseline_comparator": "vector_sum baseline",
        }
    ],
}
(results_dir / "benchmark_manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

summary = {
    "status": "completed",
    "benchmark_targets": ["vector_stats_benchmark"],
    "primary_metrics": {
        case["name"]: {
            "mean_ns": case["mean_ns"],
            "items_per_second": case["items_per_second"],
            "memory_bytes": case["memory_bytes"],
        }
        for case in raw["cases"]
    },
    "anomalies": [],
    "recommended_action": "continue",
}
(results_dir / "benchmark_summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
last_benchmark_summary = {
    "status": "completed",
    "build_status": "built",
    "test_status": "passed",
    "benchmark_targets": ["vector_stats_benchmark"],
    "primary_metrics": summary["primary_metrics"],
    "baseline_deltas": {},
    "anomalies": [],
    "recommended_action": "continue",
    "updated_at": "2026-04-17T00:00:00Z",
}
(monitoring_dir / "last_benchmark_summary.json").write_text(
    json.dumps(last_benchmark_summary, indent=2, ensure_ascii=False) + "\n",
    encoding="utf-8",
)
PY

ROBOTICS_PROJECT="$HOME/robotics-slam-project"
mkdir -p "$ROBOTICS_PROJECT"
cp -a "$SCRIPT_DIR/../fixtures/robotics_slam_project/." "$ROBOTICS_PROJECT/"

bash "$SCRIPT_DIR/check_unattended_mainline.sh" --skip-reviewer-check "$ROBOTICS_PROJECT"
cmake -S "$ROBOTICS_PROJECT" -B "$ROBOTICS_PROJECT/build" -DCMAKE_BUILD_TYPE=Release
cmake --build "$ROBOTICS_PROJECT/build" -- -j2
(cd "$ROBOTICS_PROJECT/build" && ctest --output-on-failure)
mkdir -p "$ROBOTICS_PROJECT/results" "$ROBOTICS_PROJECT/monitoring" "$ROBOTICS_PROJECT/profiles"
"$ROBOTICS_PROJECT/build/bin/slam_offline_eval" \
  --trajectory-output "$ROBOTICS_PROJECT/results/trajectory_summary.json" \
  --perception-output "$ROBOTICS_PROJECT/results/perception_summary.json"

python3 - "$ROBOTICS_PROJECT" <<'PY'
import json
import sys
from pathlib import Path

project = Path(sys.argv[1])
trajectory = json.loads((project / "results" / "trajectory_summary.json").read_text(encoding="utf-8"))
perception = json.loads((project / "results" / "perception_summary.json").read_text(encoding="utf-8"))
if trajectory.get("status") != "completed" or trajectory.get("ate", 0) <= 0 or trajectory.get("fps", 0) <= 0:
    raise RuntimeError(trajectory)
if perception.get("status") != "completed" or perception.get("map", 0) <= 0 or perception.get("fps", 0) <= 0:
    raise RuntimeError(perception)
summary = {
    "status": "completed",
    "build_status": "built",
    "test_status": "passed",
    "trajectory_metrics": {
        "ate": trajectory["ate"],
        "rpe": trajectory["rpe"],
        "tracking_rate": trajectory["tracking_rate"],
        "fps": trajectory["fps"],
        "latency_ms": trajectory["latency_ms"],
    },
    "perception_metrics": {
        "map": perception["map"],
        "precision": perception["precision"],
        "recall": perception["recall"],
        "fps": perception["fps"],
        "latency_ms": perception["latency_ms"],
    },
    "failure_buckets": {
        "tracking_loss": trajectory["failure_buckets"]["tracking_loss"],
        "missed_objects": perception["failure_buckets"]["missed_objects"],
    },
    "recommended_action": "continue",
    "updated_at": "2026-04-17T00:00:00Z",
}
(project / "monitoring" / "last_robotics_summary.json").write_text(
    json.dumps(summary, indent=2, ensure_ascii=False) + "\n",
    encoding="utf-8",
)
PY

ROS2_PROJECT="$HOME/robotics-slam-ros2-project"
mkdir -p "$ROS2_PROJECT"
cp -a "$SCRIPT_DIR/../fixtures/robotics_slam_ros2_project/." "$ROS2_PROJECT/"

bash "$SCRIPT_DIR/check_unattended_mainline.sh" --skip-reviewer-check "$ROS2_PROJECT"
bash -lc 'source /opt/ros/humble/setup.bash && colcon build --base-paths "'"$ROS2_PROJECT"'/src" --packages-select slam_ros2_fixture --build-base "'"$ROS2_PROJECT"'/build" --install-base "'"$ROS2_PROJECT"'/install" --event-handlers console_direct+ --cmake-args -DCMAKE_BUILD_TYPE=Release'
bash -lc 'source /opt/ros/humble/setup.bash && colcon test --packages-select slam_ros2_fixture --build-base "'"$ROS2_PROJECT"'/build" --install-base "'"$ROS2_PROJECT"'/install" --event-handlers console_direct+ --return-code-on-test-failure'
bash -lc 'source /opt/ros/humble/setup.bash && colcon test-result --test-result-base "'"$ROS2_PROJECT"'/build" --verbose'
mkdir -p "$ROS2_PROJECT/results" "$ROS2_PROJECT/monitoring" "$ROS2_PROJECT/profiles"
bash -lc 'source /opt/ros/humble/setup.bash && source "'"$ROS2_PROJECT"'/install/setup.bash" && ros2 run slam_ros2_fixture slam_ros2_offline_eval --trajectory-output "'"$ROS2_PROJECT"'/results/trajectory_summary.json" --perception-output "'"$ROS2_PROJECT"'/results/perception_summary.json"'

python3 - "$ROS2_PROJECT" <<'PY'
import json
import sys
from pathlib import Path

project = Path(sys.argv[1])
trajectory = json.loads((project / "results" / "trajectory_summary.json").read_text(encoding="utf-8"))
perception = json.loads((project / "results" / "perception_summary.json").read_text(encoding="utf-8"))
if trajectory.get("status") != "completed" or trajectory.get("ate", 0) <= 0 or trajectory.get("fps", 0) <= 0:
    raise RuntimeError(trajectory)
if perception.get("status") != "completed" or perception.get("map", 0) <= 0 or perception.get("fps", 0) <= 0:
    raise RuntimeError(perception)
(project / "build" / "build_report.json").write_text(
    json.dumps({"configure_status": "configured", "build_status": "built", "test_status": "passed"}, indent=2, ensure_ascii=False) + "\n",
    encoding="utf-8",
)
(project / "monitoring" / "last_robotics_summary.json").write_text(
    json.dumps(
        {
            "status": "completed",
            "build_status": "built",
            "test_status": "passed",
            "trajectory_metrics": {
                "ate": trajectory["ate"],
                "rpe": trajectory["rpe"],
                "tracking_rate": trajectory["tracking_rate"],
                "fps": trajectory["fps"],
                "latency_ms": trajectory["latency_ms"],
            },
            "perception_metrics": {
                "map": perception["map"],
                "precision": perception["precision"],
                "recall": perception["recall"],
                "fps": perception["fps"],
                "latency_ms": perception["latency_ms"],
            },
            "failure_buckets": {
                "tracking_loss": trajectory["failure_buckets"]["tracking_loss"],
                "missed_objects": perception["failure_buckets"]["missed_objects"],
            },
            "recommended_action": "continue",
            "updated_at": "2026-04-17T00:00:00Z",
        },
        indent=2,
        ensure_ascii=False,
    ) + "\n",
    encoding="utf-8",
)
PY

CUDA_PROJECT="$HOME/cuda-mixed-project"
mkdir -p "$CUDA_PROJECT"
cp -a "$SCRIPT_DIR/../fixtures/cuda_mixed_project/." "$CUDA_PROJECT/"

if command -v nvcc >/dev/null 2>&1 && command -v nvidia-smi >/dev/null 2>&1 && command -v nsys >/dev/null 2>&1; then
  bash "$SCRIPT_DIR/check_unattended_mainline.sh" --skip-reviewer-check "$CUDA_PROJECT"
  cmake -S "$CUDA_PROJECT" -B "$CUDA_PROJECT/build" -DCMAKE_BUILD_TYPE=Release
  cmake --build "$CUDA_PROJECT/build" -- -j2
  (cd "$CUDA_PROJECT/build" && ctest --output-on-failure)
  mkdir -p "$CUDA_PROJECT/results" "$CUDA_PROJECT/monitoring" "$CUDA_PROJECT/profiles"
  "$CUDA_PROJECT/build/bin/cuda_mixed_benchmark" --output "$CUDA_PROJECT/results/cuda_mixed_raw.json"

  python3 - "$CUDA_PROJECT" <<'PY'
import json
import subprocess
import sys
from pathlib import Path

project = Path(sys.argv[1])
raw = json.loads((project / "results" / "cuda_mixed_raw.json").read_text(encoding="utf-8"))
case = raw["cases"][0]
if raw.get("benchmark") != "cuda_mixed_benchmark" or case["kernel_ms"] <= 0 or case["throughput_gbps"] <= 0:
    raise RuntimeError(raw)
manifest = {
    "project_stack": "cpp_algorithm",
    "runtime_profile": "cpu_cuda_mixed",
    "benchmarks": [
        {
            "target": "cuda_mixed_benchmark",
            "binary": str(project / "build" / "bin" / "cuda_mixed_benchmark"),
            "timeout_seconds": 60,
            "repeat_count": raw["repeat"],
            "parser_type": "custom_json",
            "baseline_comparator": "cpu vector add baseline",
        }
    ],
}
(project / "results" / "benchmark_manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
summary = {
    "status": "completed",
    "benchmark_targets": ["cuda_mixed_benchmark"],
    "primary_metrics": {
        "kernel_ms": case["kernel_ms"],
        "h2d_ms": case["h2d_ms"],
        "d2h_ms": case["d2h_ms"],
        "throughput_gbps": case["throughput_gbps"],
    },
    "anomalies": [],
    "recommended_action": "continue",
}
(project / "results" / "benchmark_summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
(project / "build" / "build_report.json").write_text(
    json.dumps({"configure_status": "configured", "build_status": "built", "test_status": "passed"}, indent=2, ensure_ascii=False) + "\n",
    encoding="utf-8",
)
(project / "profiles" / "nsys_summary.json").write_text(
    json.dumps(
        {
            "backend": "nsys",
            "tool_version": subprocess.check_output(["nsys", "--version"], text=True).strip(),
            "kernel_time_ms": case["kernel_ms"],
            "copy_time_ms": case["h2d_ms"] + case["d2h_ms"],
            "recommended_action": "continue",
        },
        indent=2,
        ensure_ascii=False,
    ) + "\n",
    encoding="utf-8",
)
(project / "monitoring" / "last_benchmark_summary.json").write_text(
    json.dumps(
        {
            "status": "completed",
            "build_status": "built",
            "test_status": "passed",
            "benchmark_targets": ["cuda_mixed_benchmark"],
            "primary_metrics": summary["primary_metrics"],
            "baseline_deltas": {},
            "anomalies": [],
            "recommended_action": "continue",
            "updated_at": "2026-04-17T00:00:00Z",
        },
        indent=2,
        ensure_ascii=False,
    ) + "\n",
    encoding="utf-8",
)
PY
else
  set +e
  CUDA_PREFLIGHT_OUTPUT=$(bash "$SCRIPT_DIR/check_unattended_mainline.sh" --skip-reviewer-check "$CUDA_PROJECT" 2>&1)
  CUDA_PREFLIGHT_STATUS=$?
  set -e
  if (( CUDA_PREFLIGHT_STATUS == 0 )); then
    echo "Expected CUDA fixture preflight to fail without full CUDA toolchain" >&2
    exit 1
  fi
  if [[ "$CUDA_PREFLIGHT_OUTPUT" != *"nvcc"* && "$CUDA_PREFLIGHT_OUTPUT" != *"nvidia-smi"* && "$CUDA_PREFLIGHT_OUTPUT" != *"nsys"* ]]; then
    echo "Expected CUDA preflight blocker to mention nvcc/nvidia-smi/nsys" >&2
    printf '%s\n' "$CUDA_PREFLIGHT_OUTPUT" >&2
    exit 1
  fi
fi

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
