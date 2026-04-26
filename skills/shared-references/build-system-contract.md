# Build System Contract

ARIS skills that execute code, build binaries, or dispatch GPU/robotics toolchains must agree on **where the build configuration lives** and **how commands are invoked**. Prose MUST like "run your build" silently defaults to Python when the project is actually C++, CUDA, or a ROS2 workspace. This document formalizes the cross-skill contract that replaces language-specific hardcoding with two declarative YAML files.

## Version Independence

ARIS does **not** prescribe specific compiler / CUDA toolkit / ROS2 distro / GPU compute-capability versions. Every version-bearing field (`build.cuda_arch`, `build.ros2_distro`, `build.flags`, sanitizer / profiler tool names) is **read from the user's `.aris/project.yaml` or auto-detected from the user's environment**. Skills run against whatever toolchain happens to be installed; the validation goal is "this workflow works for your project as-is", not "your project must match version X.Y of toolkit Z". The same set of skills covers a SLAM project on ROS2 Humble + CUDA 11, an LLM-inference project on CUDA 12 + cuDNN 8, a perception project on CUDA 13 + cuDNN 9, etc.

Rule of thumb: **a skill that executes code does not guess the build command.** It calls the canonical helper, which reads the project contract, which was authored once per project. If there is no contract, the helper falls back to detection — and only then to the historical Python defaults.

## Why This Contract Exists — Known Failure Modes

ARIS has been optimized for ML/PyTorch research, and the hardcoded assumptions bleed into non-ML work:

1. **`run-experiment` hardcodes `python x.py`.** When a user's project is a C++ CMake build or a ROS2 colcon workspace, the skill either errors out or — worse — silently invokes a stale Python entry point, producing results that don't reflect the actual code under study. The vast.ai sync in `run-experiment` also hardcodes `pip install -r requirements.txt`, corrupting the dependency manifest for CUDA/ROS2 projects.
2. **`vast-gpu` locks `pip install vastai`.** Remote deployment for non-Python research needs `rosdep install` (ROS2), `cmake` + `apt-get`-style system deps (C++), or direct `nvcc` invocation (CUDA) — `pip` is the wrong tool.
3. **Sanitizer + profiler + bench dispatch has no shared truth.** Each new domain tool (`compute-sanitizer`, `ncu`, `perf`, `launch_testing`) would need to reinvent "how do I build and run this project?" inside its own SKILL.md. Without a contract, 14 new skills drift within a quarter.

All three pathologies share one cause: skill prose MUST without a **machine-enforceable build contract**.

## Required Components (per the Integration Contract)

This contract implements the six components of `integration-contract.md`:

### 1. Activation predicate

A build-system dispatch fires when the skill executes code, compiles a binary, or invokes a domain-specific toolchain. Observable signals:

- `[ -f .aris/project.yaml ]` — explicit project contract present
- `[ -f CMakeLists.txt ] || [ -f Makefile ] || [ -f package.xml ] || [ -f Cargo.toml ]` — build-system fingerprint on disk
- Skill name matches `/cpp-*`, `/ros2-*`, `/cuda-*`, `/tensorrt-*` — domain-specific skills always dispatch

When none of the above hold, the helper falls back to Python defaults (preserves ML backward compatibility).

### 2. Canonical helper

One implementation, `tools/project_contract.py`. All callers invoke the same entrypoint:

- `python3 tools/project_contract.py validate` — schema-check `.aris/project.yaml`
- `python3 tools/project_contract.py get-language` — print detected/declared language
- `python3 tools/project_contract.py get-frameworks` — print the frameworks list (e.g. `ros2 cuda cudnn tensorrt`)
- `python3 tools/project_contract.py get-build-cmd` — print the build invocation
- `python3 tools/project_contract.py get-run-cmd` — print the run invocation
- `python3 tools/project_contract.py get-bench-cmd` — print the benchmark invocation
- `python3 tools/project_contract.py get-metrics` — print the domain-specific primary metrics list
- `python3 tools/project_contract.py install-deps` — dispatch dependency install (`pip` / `colcon build` / `cmake -B build` / `nvcc compile`)
- `python3 tools/project_contract.py init` — scaffold `.aris/project.yaml` from detection

Container execution is an **optional** separate helper, `tools/container_run.sh` (parses `.aris/container.yaml`). Skills invoke it **only when the user has declared a container contract**. Otherwise, skills execute on whatever environment is active — local workstation, remote SSH target, user's own Docker / Podman / Kubernetes pod, etc. Host execution is a first-class path, not a fallback; container dispatch is opt-in isolation.

### 3. Concrete artifact

- `.aris/project.yaml` — the project contract itself (authored once per project)
- `.aris/container.yaml` — the container dispatcher config (only when ros2/cuda)
- Per-skill audit JSONs: `BUILD_ARTIFACT.json`, `BENCHMARK_RESULT.json`, `SANITIZER_AUDIT.json`, `COMPLEXITY_AUDIT.json`, `ROS2_LAUNCH_TEST_AUDIT.json`, `CUDA_SANITIZER_AUDIT.json`, etc. — each follows the 10-field schema in `assurance-contract.md`

### 4. Visible checklist

Each domain-specific skill (cpp-*, ros2-*, cuda-*, tensorrt-*) renders a pre-flight checklist at Phase 1:

```
📋 Pre-flight (build system contract):
   [ ] 1. .aris/project.yaml present or auto-detect succeeded
   [ ] 2. project_contract.py validate → exit 0
   [ ] 3. For ros2/cuda frameworks: .aris/container.yaml present + container_run.sh --probe → exit 0
   [ ] 4. Build command resolved: $(project_contract.py get-build-cmd)
   [ ] 5. HALT if any row is unchecked
```

### 5. Backfill / repair

`python3 tools/project_contract.py init [--language cpp|ros2|cuda|rust] [--frameworks ...]` generates `.aris/project.yaml` from detection. Users can re-run to regenerate after project changes. `container_run.sh --probe` probes the container runtime + writes `.aris/container.yaml`.

### 6. Verifier

- `tools/verify_cpp_project.sh` — clean compile + sanitizers pass + benchmark CV < 5% → `CPP_INTEGRITY_REPORT.json`
- `tools/verify_ros2_project.sh` — colcon test + launch_testing + bag replay → `ROS2_INTEGRITY_REPORT.json`
- `tools/verify_cuda_project.sh` — build + compute-sanitizer + Nsight profile → `CUDA_INTEGRITY_REPORT.json`
- `tools/verify_paper_audits.sh` — extended to gate per-domain audits at `assurance: submission`

Each verifier emits a structured report callers can parse and returns a non-zero exit code on block.

## `.aris/project.yaml` Schema

```yaml
# Required
language: cpp                               # python | cpp | rust | polyglot
venue_family: robotics                      # theory | pl | systems | db | graphics | hpc | robotics | gpu | ml

# Optional — frameworks active; drives domain-skill dispatch
frameworks: [ros2, cuda, cudnn, tensorrt]

# Build config
build:
  system: colcon                            # make | cmake | cargo | colcon | custom
  cmd: "colcon build --symlink-install"
  flags: ["-O3", "-DNDEBUG"]
  cuda_arch: "sm_86"                        # required when cuda in frameworks
  ros2_distro: jazzy                        # required when ros2 in frameworks

# Run / bench
run:
  cmd: "./build/app --input data/in.txt"
bench:
  harness: google-benchmark                 # google-benchmark | catch2 | rosbag-replay | cuda-eventtimer | custom
  cmd: "./build/bench --benchmark_format=json"
  iterations: 10

# Sanitizers (any failing run blocks submission assurance)
sanitizers:
  cpu: [address, undefined, thread]         # maps to -fsanitize=...
  gpu: [memcheck, racecheck, synccheck, initcheck]  # maps to compute-sanitizer --tool=...

# Profile
profile:
  cpu_tool: perf                            # perf | valgrind | instruments
  gpu_tool: nsight-compute                  # nsight-compute | nsight-systems | nvprof

# Primary metrics (domain-specific)
metrics:
  cpp: [wall_time_ms, peak_rss_kb, cache_misses, throughput_ops_sec]
  ros2: [control_loop_freq_hz, topic_latency_p99_ms, node_uptime_s, tf_lookup_error_rate]
  cuda: [kernel_time_us, occupancy_pct, warp_execution_efficiency, dram_throughput_gbs]
```

## `.aris/container.yaml` Schema (optional)

Author this only when you want ARIS to dispatch builds/runs into a container. If absent, all skills execute on the host. The schema:

```yaml
runtime: auto                   # auto-detect: docker | podman | distrobox | toolbx
name: my-cpp-dev                # user's own container name — ARIS does not ship one
workdir: /workspace
mounts:
  - source: .                   # host project root
    target: /workspace
pre_exec:                       # sourced before each dispatched task
  - "source /opt/ros/jazzy/setup.bash"        # only if using ROS2
  - "export PATH=/usr/local/cuda/bin:$PATH"   # only if using CUDA
env:
  CUDA_VISIBLE_DEVICES: "0"
```

**Runtime environment options** — ARIS does not assume any particular deployment, and ARIS does not ship a container. The user's project brings its own environment:

| Environment | `.aris/container.yaml` | What skills do |
|---|---|---|
| Local workstation (tools installed) | absent | Execute directly on host |
| Remote SSH (same as ML vast.ai flow but for C++/ROS2/CUDA) | absent; use `run-experiment` SSH path | Execute via SSH |
| User's own Docker / Podman container | present, `name:` = user's container | Dispatch via `container_run.sh` |
| Kubernetes pod / CI runner | skill runs inside the pod; no container.yaml needed | Execute directly |
| `tests/container/` ARIS self-check | `$ARIS_TEST_CONTAINER` env var points to a user-provided test container | ARIS CI helpers only (not user-facing runtime) |

`tests/container/` targets a *user-provided* test container chosen via `$ARIS_TEST_CONTAINER` (or `.aris/container.yaml`); it is ARIS's own CI self-check, not a deployment requirement.

## Auto-Detection Fallback

When `.aris/project.yaml` is absent, the helper detects from project files in this order:

| Signal | Inferred language | Notes |
|--------|-------------------|-------|
| `package.xml` + any `CMakeLists.txt` mentioning `ament_cmake` | `ros2` (framework) | venue_family defaults to `robotics` |
| Any `.cu` or `.cuh` file | `cuda` (framework) added to cpp | venue_family defaults to `gpu` |
| `CMakeLists.txt` or `Makefile` (no ROS2 markers, no `.cu`) | `cpp` | venue_family defaults to `systems` |
| `Cargo.toml` | `rust` | venue_family defaults to `systems` |
| `pyproject.toml` or `requirements.txt` | `python` | venue_family defaults to `ml` |
| None of the above | `python` | Preserves ML backward compat |

Detection is only a fallback — it emits a warning recommending `project_contract.py init` to persist the inference.

## Relationship to Other Contracts

- **`integration-contract.md`** — this contract implements the build-dispatch integration under that umbrella.
- **`assurance-contract.md`** — the audit JSONs emitted by cpp-*/ros2-*/cuda-* skills follow the 10-field schema defined there.
- **`effort-contract.md`** — `language`/`frameworks` are orthogonal to `effort` and `assurance`; they compose freely.
- **`experiment-integrity.md`** — when `language ≠ python`, `experiment-integrity` dispatches through this contract to get the right build/run/bench commands.

## Known ARIS Integrations Under This Contract

| Integration | Predicate | Helper | Artifact | Checklist | Backfill | Verifier |
|---|---|---|---|---|---|---|
| C++ build/bench/sanitize | `language: cpp` in `.aris/project.yaml` | `project_contract.py get-*` + `cpp-*` skills | `BUILD_ARTIFACT.json`, `BENCHMARK_RESULT.json`, `SANITIZER_AUDIT.json` | Pre-flight in each cpp-* skill | `project_contract.py init --language cpp` | `verify_cpp_project.sh` |
| ROS2 workspace | `ros2` in `frameworks` | `container_run.sh` + `ros2-*` skills | `ROS2_BUILD_ARTIFACT.json`, `ROS2_LAUNCH_TEST_AUDIT.json`, `ROS2_REALTIME_AUDIT.json` | Pre-flight in each ros2-* skill | `container_run.sh --probe` + `project_contract.py init --frameworks ros2` | `verify_ros2_project.sh` |
| CUDA kernels | `cuda` in `frameworks` | `container_run.sh` + `cuda-*` skills | `CUDA_BUILD_ARTIFACT.json`, `CUDA_SANITIZER_AUDIT.json`, `CUDA_PROFILE_REPORT.json`, `CUDA_CORRECTNESS_AUDIT.json` | Pre-flight in each cuda-* skill | `container_run.sh --probe` + `project_contract.py init --frameworks cuda` | `verify_cuda_project.sh` |
| TensorRT engines | `tensorrt` in `frameworks` | `tensorrt-engine-audit` skill via `container_run.sh` | `TRT_ENGINE_AUDIT.json` | Pre-flight in tensorrt-engine-audit | `container_run.sh --probe` | `verify_paper_audits.sh` (aggregated) |

## See Also

- `shared-references/integration-contract.md` — umbrella contract
- `shared-references/assurance-contract.md` — audit JSON schema
- `tools/project_contract.py` — canonical helper
- `tools/container_run.sh` — container dispatcher
- `tools/verify_cpp_project.sh`, `verify_ros2_project.sh`, `verify_cuda_project.sh` — per-domain verifiers
