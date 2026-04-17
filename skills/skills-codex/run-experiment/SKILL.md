---
name: run-experiment
description: Deploy and run experiments on local or remote hosts. Supports the existing ML training path plus CMake-first compiled benchmark projects. Use when user says "run experiment", "deploy to server", "跑实验", or needs to launch training jobs or compiled benchmarks.
argument-hint: [experiment-description]
allowed-tools: Bash(*), Read, Grep, Glob, Edit, Write, Agent
---

# Run Experiment

Deploy and run experiment: $ARGUMENTS

## Unattended Safe Mode

If `CODEX.md -> ## Autonomy Profile` sets `autonomy_mode: unattended_safe`:

- `allow_auto_cloud: false` means do **not** auto-provision a new vast.ai instance; use an already-running instance or block with an explicit reason in `AUTONOMY_STATE.json`
- `require_watchdog: true` means long-running remote or background jobs must be registered with `tools/watchdog.py` before this skill exits
- `require_wandb_for_unattended_training: true` means long unattended training needs `wandb: true` and `wandb_project`; otherwise stop after the smallest credible sanity run
- `runtime_profile: cpu_benchmark` means this skill must treat CTest + benchmark artifacts as the primary monitoring path; W&B becomes optional in that branch
- `runtime_profile: cpu_cuda_mixed` means this skill must treat CTest + benchmark artifacts + GPU profiler summaries as the primary monitoring path
- `runtime_profile: slam_offline` means this skill must treat CTest + offline replay/eval summaries (`trajectory_summary.json`, `perception_summary.json`) as the primary monitoring path
- update `AUTONOMY_STATE.json` before launch, after watchdog registration, and when deployment is blocked or complete

## Execution Profile Routing

Read `CODEX.md -> ## Execution Profile` before doing anything else. Use it to choose one of four paths:

- `project_stack: python_ml` / `runtime_profile: training` -> keep the existing Python / GPU / W&B-oriented deployment path
- `project_stack: cpp_algorithm` / `runtime_profile: cpu_benchmark` -> use a compiled-project path built around `cmake configure -> build -> ctest -> benchmark`, with machine-readable benchmark outputs
- `project_stack: cpp_algorithm` / `runtime_profile: cpu_cuda_mixed` -> use a compiled-project path built around `cmake configure -> build -> ctest -> benchmark/profile`, with CMake CUDA + GPU profiling artifacts
- `project_stack: robotics_slam` / `runtime_profile: slam_offline` -> use a robotics path built around `configure/build -> ctest -> offline replay/eval`, with trajectory/perception summaries and optional `cmake_ros2` adapter steps

The host still comes from `CODEX.md -> ## GPU Configuration`. In compiled or robotics mode, `gpu: local | remote` means **execution host type**, not that a GPU must exist unless the CUDA profile explicitly requires one.

## Workflow

### Step 1: Detect Environment

Read the project's `CODEX.md` to determine the experiment environment:

- **Local GPU** (`gpu: local`): Look for local CUDA/MPS setup info
- **Remote server** (`gpu: remote`): Look for SSH alias, conda env, code directory
- **Vast.ai** (`gpu: vast`): Check for `vast-instances.json` at project root — if a running instance exists, use it. Also check `CODEX.md` for a `## Vast.ai` section.

**Vast.ai detection priority:**
1. If `CODEX.md` has `gpu: vast` or a `## Vast.ai` section:
   - If `vast-instances.json` exists and has a running instance → use that instance
   - If no running instance and `CODEX.md -> ## Autonomy Profile` has `allow_auto_cloud: false` → stop and record a blocker in `AUTONOMY_STATE.json`
   - Otherwise → call `/vast-gpu provision` which analyzes the task, presents cost-optimized GPU options, and rents the user's choice
2. If no server info is found in `CODEX.md`, default to `gpu: local` and attempt to use locally available GPUs (via `nvidia-smi`). If no local GPU detected, log a warning and attempt CPU execution for small-scale experiments.

### Step 2: Pre-flight Check

Check the target resources that match the execution profile:

- training path -> GPU availability on the target machine
- compiled benchmark path -> toolchain and host availability (`cmake`, compiler, `ctest`, `make`/`ninja`)
- CUDA mixed path -> all of the above plus `nvcc`, `nvidia-smi`, and the requested profiler backend (`perf`, `nsys`, or `ncu`)
- robotics offline path -> all of the above plus `colcon` / `ros2` when `build_system: cmake_ros2`, and the offline replay/eval entrypoint for dataset / rosbag / simulator runs

**Training path GPU checks:**

**Remote (SSH):**
```bash
ssh <server> nvidia-smi --query-gpu=index,memory.used,memory.total --format=csv,noheader
```

**Remote (Vast.ai):**
```bash
ssh -p <PORT> root@<HOST> nvidia-smi --query-gpu=index,memory.used,memory.total --format=csv,noheader
```
(Read `ssh_host` and `ssh_port` from `vast-instances.json`, or run `vastai ssh-url <INSTANCE_ID>` which returns `ssh://root@HOST:PORT`)

**Local:**
```bash
nvidia-smi --query-gpu=index,memory.used,memory.total --format=csv,noheader
# or for Mac MPS:
python -c "import torch; print('MPS available:', torch.backends.mps.is_available())"
```

Free GPU = memory.used < 500 MiB.

### Step 2.5: Toolchain Pre-flight (when using compiled or robotics execution profiles)

Before syncing or launching compiled benchmarks, verify the host can actually build and run the project:

**Remote:**
```bash
ssh <server> "cmake --version && ctest --version && c++ --version && (ninja --version || make --version)"
```

**Local:**
```bash
cmake --version
ctest --version
c++ --version
ninja --version || make --version
```

If `runtime_profile: cpu_cuda_mixed`, also verify `nvcc`, `nvidia-smi`, and the requested profiler (`perf`, `nsys`, or `ncu`) now instead of after the run fails.

If `project_stack: robotics_slam` and `build_system: cmake_ros2`, also verify `colcon` and `ros2` now instead of after the run fails.

### Step 3: Sync Code (Remote Only)

Check the project's `CODEX.md` for a `code_sync` setting. If not specified, default to `rsync`.

#### Option A: rsync (default)

Only sync necessary source/build files — NOT data, checkpoints, or large files. The exact include set must match the execution profile:

```bash
# python_ml
rsync -avz --include='*.py' --exclude='*' <local_src>/ <server>:<remote_dst>/

# cpp_algorithm / robotics_slam / cmake / cmake_ros2
rsync -avz \
  --include='CMakeLists.txt' --include='*.cmake' --include='package.xml' \
  --include='*.cc' --include='*.cpp' --include='*.cxx' --include='*.cu' --include='*.cuh' \
  --include='*.h' --include='*.hpp' --include='*.ipp' \
  --include='*.json' --include='*.yaml' --include='*.yml' --include='*.xml' --include='*.rviz' \
  --include='*.launch.py' --include='*.sh' --include='*/' --exclude='*' \
  <local_src>/ <server>:<remote_dst>/
```

#### Option B: git (when `code_sync: git` is set in CODEX.md)

Push local changes to remote repo, then pull on the server:
```bash
# 1. Push from local
git add -A && git commit -m "sync: experiment deployment" && git push

# 2. Pull on server
ssh <server> "cd <remote_dst> && git pull"
```

Benefits: version-tracked, multi-server sync with one push, no rsync include/exclude rules needed.

#### Option C: Vast.ai instance

Sync code to the vast.ai instance (always rsync, code dir is `/workspace/project/`):
```bash
rsync -avz -e "ssh -p <PORT>" \
  --include='*.py' --include='*.yaml' --include='*.yml' --include='*.json' \
  --include='*.txt' --include='*.sh' --include='*/' \
  --exclude='*.pt' --exclude='*.pth' --exclude='*.ckpt' \
  --exclude='__pycache__' --exclude='.git' --exclude='data/' \
  --exclude='wandb/' --exclude='outputs/' \
  ./ root@<HOST>:/workspace/project/
```

If `requirements.txt` exists, install dependencies:
```bash
scp -P <PORT> requirements.txt root@<HOST>:/workspace/
ssh -p <PORT> root@<HOST> "pip install -q -r /workspace/requirements.txt"
```

### Step 3.5: W&B Integration (when `wandb: true` in CODEX.md)

**Skip this step entirely if `wandb` is not set or is `false` in `CODEX.md`, or if `runtime_profile: cpu_benchmark`, `cpu_cuda_mixed`, or `slam_offline`.**

Before deploying, ensure the experiment scripts have W&B logging:

1. **Check if wandb is already in the script** — look for `import wandb` or `wandb.init`. If present, skip to Step 4.

2. **If not present, add W&B logging** to the training script:
   ```python
   import wandb
   wandb.init(project=WANDB_PROJECT, name=EXP_NAME, config={...hyperparams...})

   # Inside training loop:
   wandb.log({"train/loss": loss, "train/lr": lr, "step": step})

   # After eval:
   wandb.log({"eval/loss": eval_loss, "eval/ppl": ppl, "eval/accuracy": acc})

   # At end:
   wandb.finish()
   ```

3. **Metrics to log** (add whichever apply to the experiment):
   - `train/loss` — training loss per step
   - `train/lr` — learning rate
   - `eval/loss`, `eval/ppl`, `eval/accuracy` — eval metrics per epoch
   - `gpu/memory_used` — GPU memory (via `torch.cuda.max_memory_allocated()`)
   - `speed/samples_per_sec` — throughput
   - Any custom metrics the experiment already computes

4. **Verify wandb login on the target machine:**
   ```bash
   ssh <server> "wandb status"  # should show logged in
   # If not logged in:
   ssh <server> "wandb login <WANDB_API_KEY>"
   ```

> The W&B project name and API key come from `CODEX.md` (see example below). The experiment name is auto-generated from the script name + timestamp. In unattended-safe mode with `require_wandb_for_unattended_training: true`, this step is a hard prerequisite for any long-running training job.

### Step 4: Deploy

If `project_stack: cpp_algorithm` and `runtime_profile: cpu_benchmark`, use the compiled-project deployment contract below instead of the Python training commands.

If `project_stack: cpp_algorithm` and `runtime_profile: cpu_cuda_mixed`, use the CUDA mixed deployment contract below instead of the Python training commands.

If `project_stack: robotics_slam` and `runtime_profile: slam_offline`, use the robotics offline deployment contract below instead of the Python training commands.

#### Compiled benchmark mode (remote host)

1. Configure and build:
```bash
ssh <server> "cd <remote_dst> && cmake -S . -B <build_dir> -DCMAKE_BUILD_TYPE=<build_type> && cmake --build <build_dir> -j$(nproc)"
```

2. Run correctness gate before any long benchmark sweep:
```bash
ssh <server> "cd <remote_dst> && ctest --test-dir <build_dir> --output-on-failure"
```

3. Launch the benchmark in its own session:
```bash
ssh <server> "screen -dmS <exp_name> bash -c '\
  cd <remote_dst> && \
  ./<build_dir>/bin/<benchmark_binary> --output results/<benchmark_name>.json 2>&1 | tee <log_file>'"
```

4. Record standard artifacts for downstream skills:
- `build/build_report.json`
- `results/benchmark_manifest.json`
- `results/benchmark_summary.json`
- `profiles/nsys_summary.json` (or the requested profiler equivalent) when `runtime_profile: cpu_cuda_mixed`

#### CUDA mixed mode (local or remote host)

1. Configure and build with CMake CUDA enabled:
```bash
cmake -S . -B <build_dir> -DCMAKE_BUILD_TYPE=<build_type>
cmake --build <build_dir> -j$(nproc)
```

2. Run the correctness gate before any long GPU sweep:
```bash
ctest --test-dir <build_dir> --output-on-failure
```

3. Launch the benchmark and profile path:
```bash
./<build_dir>/bin/<benchmark_binary> --output results/<benchmark_name>.json
# profiler backend from CODEX.md -> ## CUDA Profile
nsys profile --output profiles/<benchmark_name> ./<build_dir>/bin/<benchmark_binary> ...
```

4. Record standard artifacts for downstream skills:
- `build/build_report.json`
- `results/benchmark_manifest.json`
- `results/benchmark_summary.json`
- `profiles/nsys_summary.json` or equivalent

#### Robotics / SLAM offline mode (local or remote host)

1. Configure and build:
```bash
cmake -S . -B <build_dir> -DCMAKE_BUILD_TYPE=<build_type>
cmake --build <build_dir> -j$(nproc)
```
If `build_system: cmake_ros2`, use:
```bash
colcon build --base-paths . --build-base <build_dir>
```

2. Run the correctness gate before any offline replay/eval:
```bash
ctest --test-dir <build_dir> --output-on-failure
```

3. Launch the offline replay / evaluation path on dataset / rosbag / simulator inputs:
```bash
./<build_dir>/bin/<offline_eval_binary> --trajectory-output results/trajectory_summary.json --perception-output results/perception_summary.json
```

4. Record standard artifacts for downstream skills:
- `build/build_report.json`
- `results/trajectory_summary.json`
- `results/perception_summary.json`
- `monitoring/last_robotics_summary.json`

If unattended-safe mode requires watchdog coverage, register the session as a benchmark workload:
```bash
python3 tools/watchdog.py --register '{"name":"<exp_name>","type":"benchmark","session":"<exp_name>","session_type":"screen","gpus":[]}'
```

#### Compiled benchmark mode (local host)

```bash
cmake -S . -B <build_dir> -DCMAKE_BUILD_TYPE=<build_type>
cmake --build <build_dir> -j$(nproc 2>/dev/null || sysctl -n hw.logicalcpu)
ctest --test-dir <build_dir> --output-on-failure
./<build_dir>/bin/<benchmark_binary> --output results/<benchmark_name>.json 2>&1 | tee <log_file>
```

Otherwise, use the existing training-oriented path below.

#### Remote (via SSH + screen)

For each experiment, create a dedicated screen session with GPU binding:
```bash
ssh <server> "screen -dmS <exp_name> bash -c '\
  eval \"\$(<conda_path>/conda shell.bash hook)\" && \
  conda activate <env> && \
  CUDA_VISIBLE_DEVICES=<gpu_id> python <script> <args> 2>&1 | tee <log_file>'"
```

#### Vast.ai instance

No conda needed — the Docker image has the environment. Use `/workspace/project/` as working dir:
```bash
ssh -p <PORT> root@<HOST> "screen -dmS <exp_name> bash -c '\
  cd /workspace/project && \
  CUDA_VISIBLE_DEVICES=<gpu_id> python <script> <args> 2>&1 | tee /workspace/<log_file>'"
```

After launching, update the `experiment` field in `vast-instances.json` for this instance.

If unattended-safe mode requires watchdog coverage, register the new session immediately after launch:

```bash
python3 tools/watchdog.py --register '{"name":"<exp_name>","type":"training","session":"<exp_name>","session_type":"screen","gpus":[<gpu_id>]}'
```

#### Local

```bash
# Linux with CUDA
CUDA_VISIBLE_DEVICES=<gpu_id> python <script> <args> 2>&1 | tee <log_file>

# Mac with MPS (PyTorch uses MPS automatically)
python <script> <args> 2>&1 | tee <log_file>
```

For local long-running jobs, use `run_in_background: true` to keep the conversation responsive.

### Step 5: Verify Launch

**Remote (SSH):**
```bash
ssh <server> "screen -ls"
```

**Remote (Vast.ai):**
```bash
ssh -p <PORT> root@<HOST> "screen -ls"
```

**Local:**
Check process is running and GPU is allocated.

### Step 6: Feishu Notification (if configured)

After deployment is verified, check `~/.codex/feishu.json`:
- Send `experiment_done` notification: which experiments launched, which GPUs, estimated time
- If config absent or mode `"off"`: skip entirely (no-op)

### Step 7: Auto-Destroy Vast.ai Instance (when `gpu: vast` and `auto_destroy: true`)

**Skip this step if not using vast.ai or `auto_destroy` is `false`.**

After the experiment completes (detected via `/monitor-experiment` or screen session ending):

1. **Download results** from the instance:
   ```bash
   rsync -avz -e "ssh -p <PORT>" root@<HOST>:/workspace/project/results/ ./results/
   ```

2. **Download logs**:
   ```bash
   scp -P <PORT> root@<HOST>:/workspace/*.log ./logs/
   ```

3. **Destroy the instance** to stop billing:
   ```bash
   vastai destroy instance <INSTANCE_ID>
   ```

4. **Update `vast-instances.json`** — mark status as `destroyed`.

5. **Report cost**:
   ```
   Vast.ai instance <ID> auto-destroyed.
   - Duration: ~X.X hours
   - Estimated cost: ~$X.XX
   - Results saved to: ./results/
   ```

> This ensures users are never billed for idle instances. When `auto_destroy: true` (the default), the full lifecycle is automatic: rent → setup → run → collect → destroy.

## Key Rules

- ALWAYS check the right resources first — GPUs for training profiles, toolchain + host health for compiled benchmark profiles
- Each experiment gets its own screen session + GPU (remote) or background process (local); compiled benchmark runs should use the same isolation even without GPUs
- Use `tee` to save logs for later inspection
- Run deployment commands with `run_in_background: true` to keep conversation responsive
- Report back: which GPU, which screen/process, what command, estimated time
- If multiple experiments, launch them in parallel only when the host has enough free GPUs or CPU capacity for fair comparison
- **Vast.ai cost awareness**: When using `gpu: vast`, always report the running cost. If `auto_destroy: true`, destroy the instance as soon as all experiments on it complete

## CODEX.md Example

The execution path now comes from `CODEX.md -> ## Execution Profile`, not from guesswork.

Users should add their server info to their project's `CODEX.md`:

```markdown
## Remote Server
- gpu: remote               # use pre-configured SSH server
- SSH: `ssh my-gpu-server`
- GPU: 4x A100 (80GB each)
- Conda: `eval "$(/opt/conda/bin/conda shell.bash hook)" && conda activate research`
- Code dir: `/home/user/experiments/`
- code_sync: rsync          # default. Or set to "git" for git push/pull workflow
- wandb: false              # set to "true" to auto-add W&B logging to experiment scripts
- wandb_project: my-project # W&B project name (required if wandb: true)
- wandb_entity: my-team     # W&B team/user (optional, uses default if omitted)

## Vast.ai
- gpu: vast                  # rent on-demand GPU from vast.ai
- auto_destroy: true         # auto-destroy after experiment completes (default: true)
- max_budget: 5.00           # optional: max total $ to spend per experiment

## Local Environment
- gpu: local                 # use local GPU
- Mac MPS / Linux CUDA
- Conda env: `ml` (Python 3.10 + PyTorch)
```

> **Vast.ai setup**: Run `pip install vastai && vastai set api-key YOUR_KEY`. Upload your SSH public key at https://cloud.vast.ai/manage-keys/. Set `gpu: vast` in your `CODEX.md` — `/run-experiment` will automatically rent an instance, run the experiment, and destroy it when done.

> **W&B setup**: Run `wandb login` on your server once (or set `WANDB_API_KEY` env var). The skill reads project/entity from CODEX.md and adds `wandb.init()` + `wandb.log()` to your training scripts automatically. Dashboard: `https://wandb.ai/<entity>/<project>`.

> **C++ / compiled benchmark setup**: add an `## Execution Profile` block with `project_stack: cpp_algorithm`, `build_system: cmake`, `runtime_profile: cpu_benchmark`, `test_backend: ctest`, and a `benchmark_backend` of `google_benchmark` or `custom_cli`. In that mode, `/run-experiment` expects build/test artifacts plus machine-readable benchmark output instead of a Python trainer.
> **C++ / CUDA setup**: switch `runtime_profile` to `cpu_cuda_mixed`, add `## CUDA Profile`, keep `build_system: cmake`, and expect benchmark + profiler artifacts instead of W&B.
> **Robotics / SLAM setup**: switch `project_stack` to `robotics_slam`, `runtime_profile` to `slam_offline`, add `## Robotics Profile`, and keep the execution scope inside dataset / rosbag / simulator replay instead of autonomous real-robot runs.

```markdown
## GPU Configuration
- gpu: remote
- ssh_alias: cpu-bench-host
- code_dir: ~/cpp-project

## Execution Profile
- project_stack: cpp_algorithm
- build_system: cmake
- runtime_profile: cpu_benchmark
- build_dir: build
- build_type: Release
- cmake_preset:
- test_backend: ctest
- benchmark_backend: custom_cli
- artifact_roots: build,results,monitoring
```
