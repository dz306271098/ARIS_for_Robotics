---
name: monitor-experiment
description: Monitor running experiments, check progress, and collect results from training jobs or compiled benchmarks. Use when user says "check results", "is it done", "monitor", or wants experiment output.
argument-hint: [server-alias or screen-name]
allowed-tools: Bash(ssh *), Bash(echo *), Read, Write, Edit
---

# Monitor Experiment Results

Monitor: $ARGUMENTS

## Execution Profile Routing

Read `CODEX.md -> ## Execution Profile` before collecting anything.

- `python_ml` / `runtime_profile: training` -> prefer screen output, result files, and W&B
- `cpp_algorithm` / `runtime_profile: cpu_benchmark` -> prefer build logs, CTest, benchmark JSON/CSV, and profiler artifacts
- `cpp_algorithm` / `runtime_profile: cpu_cuda_mixed` -> prefer build logs, CTest, benchmark JSON/CSV, and GPU profiler artifacts
- `robotics_slam` / `runtime_profile: slam_offline` -> prefer build logs, CTest, offline replay/eval outputs, and trajectory/perception summaries

## Workflow

### Step 1: Check What's Running

**SSH server:**
```bash
ssh <server> "screen -ls"
```

**Vast.ai instance** (read `ssh_host`, `ssh_port` from `vast-instances.json`):
```bash
ssh -p <PORT> root@<HOST> "screen -ls"
```

Also check vast.ai instance status:
```bash
vastai show instances
```

### Step 2: Collect Output from Each Screen
For each screen session, capture the last N lines:
```bash
ssh <server> "screen -S <name> -X hardcopy /tmp/screen_<name>.txt && tail -50 /tmp/screen_<name>.txt"
```

If hardcopy fails, check for log files or tee output.

### Step 3: Check for Result Files
```bash
ssh <server> "ls -lt <results_dir>/*.json 2>/dev/null | head -20"
```

If JSON/CSV/benchmark results exist, fetch and parse them:
```bash
ssh <server> "cat <results_dir>/<latest>.json"
```

### Step 3.5: Pull W&B Metrics (when `wandb: true` in CODEX.md)

**Skip this step entirely if `wandb` is not set or is `false` in `CODEX.md`, or if `runtime_profile: cpu_benchmark`, `cpu_cuda_mixed`, or `slam_offline`.**

Pull training curves and metrics from Weights & Biases via Python API:

```bash
# List recent runs in the project
ssh <server> "python3 -c \"
import wandb
api = wandb.Api()
runs = api.runs('<entity>/<project>', per_page=10)
for r in runs:
    print(f'{r.id}  {r.state}  {r.name}  {r.summary.get(\"eval/loss\", \"N/A\")}')
\""

# Pull specific metrics from a run (last 50 steps)
ssh <server> "python3 -c \"
import wandb, json
api = wandb.Api()
run = api.run('<entity>/<project>/<run_id>')
history = list(run.scan_history(keys=['train/loss', 'eval/loss', 'eval/ppl', 'train/lr'], page_size=50))
print(json.dumps(history[-10:], indent=2))
\""

# Pull run summary (final metrics)
ssh <server> "python3 -c \"
import wandb, json
api = wandb.Api()
run = api.run('<entity>/<project>/<run_id>')
print(json.dumps(dict(run.summary), indent=2, default=str))
\""
```

**What to extract:**
- **Training loss curve** — is it converging? diverging? plateauing?
- **Eval metrics** — loss, PPL, accuracy at latest checkpoint
- **Learning rate** — is the schedule behaving as expected?
- **GPU memory** — any OOM risk?
- **Run status** — running / finished / crashed?

**W&B dashboard link** (include in summary for user):
```
https://wandb.ai/<entity>/<project>/runs/<run_id>
```

> This gives the auto-review-loop richer signal than just screen output — training dynamics, loss curves, and metric trends over time.

### Step 3.6: Compiled / CUDA / Robotics Evidence

For compiled projects, also inspect these artifacts if they exist:

```bash
ls -lt build/build_report.json results/benchmark_manifest.json results/benchmark_summary.json monitoring/last_benchmark_summary.json profiles/nsys_summary.json 2>/dev/null
ls -lt results/trajectory_summary.json results/perception_summary.json monitoring/last_robotics_summary.json 2>/dev/null
```

What to extract:

- whether configure/build succeeded
- whether `ctest` passed, and which test failed if not
- benchmark metrics: runtime, throughput, memory, input scale, repeat variance
- trajectory/perception metrics: ATE, RPE, tracking rate, latency/FPS, mAP/precision/recall, failure buckets
- baseline deltas and parser confidence
- profiler evidence (`perf`, `nsys`, `ncu`, flamegraph, custom report) when the plan asked for diagnosis

### Step 4: Summarize Results

Present results in a comparison table:
```
| Experiment | Metric | Delta vs Baseline | Status |
|-----------|--------|-------------------|--------|
| Baseline  | X.XX   | —                 | done   |
| Method A  | X.XX   | +Y.Y              | done   |
```

For `cpp_algorithm`, prefer explicit rows for correctness, runtime, memory, scaling, and when relevant kernel / transfer metrics rather than squeezing everything into one metric.

For `robotics_slam`, prefer explicit rows for correctness, trajectory quality, perception quality, latency/FPS, and failure buckets rather than squeezing everything into one metric.

### Step 5: Interpret
- Compare against known baselines
- Flag unexpected results (negative delta, NaN, divergence)
- For compiled projects, flag failing tests, benchmark regressions, unexpected variance, suspicious parser output, or profiler evidence that contradicts the claimed mechanism
- Suggest next steps based on findings

### Step 5.5: Machine-Readable Summary for Unattended Mode

When `CODEX.md -> ## Autonomy Profile` sets `autonomy_mode: unattended_safe`, also save a machine-readable summary to `monitoring/last_monitor_summary.json` with:

- `status`: running / blocked / completed
- `experiments`: tracked experiment names
- `running`: still-running sessions
- `completed`: finished experiments
- `anomalies`: divergence / NaN / dead session / missing files
- `recommended_action`: continue / retry / block
- `updated_at`

If `project_stack: cpp_algorithm`, also write `monitoring/last_benchmark_summary.json` with:

- `status`: running / blocked / completed
- `build_status`: configured / built / failed
- `test_status`: passed / failed / missing
- `benchmark_targets`: tracked benchmark binaries
- `primary_metrics`: runtime / memory / throughput / scale metrics
- `baseline_deltas`: parsed comparison numbers
- `anomalies`: failed tests / parser mismatch / high variance / missing artifact
- `recommended_action`: continue / retry / block
- `updated_at`

If `project_stack: robotics_slam`, also write `monitoring/last_robotics_summary.json` with:

- `status`: running / blocked / completed
- `build_status`: configured / built / failed
- `test_status`: passed / failed / missing
- `trajectory_metrics`: ATE / RPE / tracking / drift summaries
- `perception_metrics`: mAP / precision / recall / latency / FPS summaries
- `failure_buckets`: tracking loss / drift spikes / missed detections / loop-closure issues
- `recommended_action`: continue / retry / block
- `updated_at`

Update `AUTONOMY_STATE.json` if the summary reveals a blocker.

### Step 6: Feishu Notification (if configured)

After results are collected, check `~/.codex/feishu.json`:
- Send `experiment_done` notification: results summary table, delta vs baseline
- If config absent or mode `"off"`: skip entirely (no-op)

## Key Rules
- Always show raw numbers before interpretation
- Compare against the correct baseline (same config)
- Note if experiments are still running (check progress bars, iteration counts)
- If results look wrong, inspect the source artifact that matches the execution profile before concluding: training logs/W&B for training, build/test/benchmark/profiler artifacts for compiled mode
- **Vast.ai cost awareness**: When monitoring vast.ai instances, report the running cost (hours * $/hr from `vast-instances.json`). If all experiments on an instance are done, remind the user to run `/vast-gpu destroy <instance_id>` to stop billing
