---
name: training-check
description: Periodically check experiment health metrics to catch problems early (NaN, loss divergence, idle GPUs for ML; runtime regressions, memory leaks for C++/CUDA; real-time deadline misses for ROS2). Avoids wasting compute on broken runs. Use when an experiment is running and you want automated health checks.
argument-hint: [wandb-run-path | .aris/project.yaml]
allowed-tools: Bash(*), Read, Grep, Glob, Write, Edit, Bash(codex*), Skill(codex:rescue), Skill(codex:adversarial-review)
---

# Training / Experiment Health Check

Periodically read experiment metrics to catch problems early. Do not wait until the run finishes to discover it was a waste of compute time.

## Domain dispatch (polyglot)

Consult `tools/project_contract.py` before selecting metric sources:

- `language: python` (default, ML workflows) → WandB history or training log (existing behavior, Steps 1–6 below)
- `language: cpp` or `frameworks` includes `ros2` / `cuda` → read artifacts instead:
  - C++: `BENCHMARK_RESULT.json` (throughput / wall_time CV) + `SANITIZER_AUDIT.json` (any runtime UB / leak)
  - ROS2: `ROS2_REALTIME_AUDIT.json` (control-loop freq, p99 latency) + `ROS2_LAUNCH_TEST_AUDIT.json` (node liveness)
  - CUDA: `CUDA_PROFILE_REPORT.json` (occupancy / throughput) + `CUDA_SANITIZER_AUDIT.json` (runtime race / oob)
  - "Clearly bad" in the polyglot mode: non-clean sanitizer run, occupancy drop > 20% from baseline, p99 latency exceeds deadline, benchmark CV > 10%.
  - "Clearly fine" in the polyglot mode: all audits PASS/NOT_APPLICABLE, benchmark median within 5% of baseline, sanitizer reports empty.

The judgment → Codex dispatch → action flow (Steps 2–6 below) applies identically; only the metric source changes.

## Context: $ARGUMENTS

## Constants

- WANDB_ENTITY and WANDB_PROJECT: read from CLAUDE.md or passed as argument (format: `entity/project/run_id`)
- CHECK_INTERVAL: starts at 10 minutes, then gradually increases if consistently healthy: 10 min → 20 min → 30 min → 60 min (cap)
- REVIEWER_MODEL = `gpt-5.4` — used via Codex CLI for ambiguous cases only

## When to Use

- After training is confirmed running (session alive, loss decreasing for first few steps)
- Set up via CronCreate to fire periodically during training
- **This skill checks training QUALITY, not process HEALTH.** Process health (session alive, GPU utilization) is [watchdog.py](../../tools/watchdog.py)'s job.

## Workflow

### Step 1: Read WandB Metrics

```python
import wandb
api = wandb.Api()
run = api.run("<entity>/<project>/<run_id>")
history = run.history()
```

If WandB is unreachable (API error, network issue), fall back to reading the log file directly via SSH:
```bash
ssh server "tail -100 /path/to/training.log"
```

Check these signals:
- **Loss trend**: Is training loss decreasing over the last N steps?
- **Eval metrics**: Are evaluation metrics improving (or at least not degrading)?
- **NaN / Inf**: Any NaN or Inf values in loss or gradients?
- **Spikes**: Sudden large jumps in loss (>10x normal variance)?
- **Learning rate**: Is the schedule behaving as expected?
- **Gradient norm**: Exploding or vanishing?

### Step 2: Judgment

| Signal | Judgment | Action |
|--------|----------|--------|
| NaN/Inf in loss | **Clearly bad** | Stop training, investigate |
| Loss diverging (increasing for >N steps) | **Clearly bad** | Stop training, investigate |
| Eval metrics significantly worse than baseline | **Clearly bad** | Stop training, investigate |
| Loss decreasing, metrics improving | **Clearly fine** | Continue, increase check interval |
| Loss flat but not diverging | **Unsure** | → Step 3 (Codex judgment) |
| Metrics noisy, can't tell trend | **Unsure** | → Step 3 (Codex judgment) |
| Slightly worse than baseline but still early | **Unsure** | → Step 3 (Codex judgment) |

### Step 3: Codex Judgment (only when unsure)

Only escalate to Codex when the signal is ambiguous. For clearly good or clearly bad signals, act directly.

```bash
codex exec --sandbox read-only -m gpt-5.4 "TRAINING HEALTH CHECK — need your judgment on ambiguous metrics. Read the project files directly for training logs and metrics. Respond with exactly one of: STOP, CONTINUE, or WAIT."
```

### Step 4: Act

| Decision | Action |
|----------|--------|
| **Stop** | Kill the training session. Save the WandB run URL, key metrics, and reason for stopping. Log to project notes for debugging. |
| **Continue** | Do nothing. Will be invoked again at next interval (increase interval if consistently healthy). |
| **Wait** | Do nothing but keep the current short interval (don't increase). |

## Integration with Watchdog

Training-check and [watchdog.py](../../tools/watchdog.py) operate at different levels:

| Layer | Tool | What it checks | Frequency |
|-------|------|----------------|-----------|
| Process health | watchdog.py | Session alive? GPU active? | Every 60s (continuous) |
| Training quality | training-check | Loss trend? Metrics improving? | Every 10-60 min (periodic) |

Use both together:
- Watchdog catches crashes and idle GPUs immediately
- Training-check catches subtle quality issues (loss plateau, metric degradation)

## Rules

- Do not stop training on first sign of noise — some loss spikes are normal. Look at **trends over multiple checkpoints**.
- When stopping training, always save the WandB run URL and key metrics as evidence.
- If both WandB and log files are unreachable, report the connectivity issue and try again next interval. Do not assume training is broken.
- Gradually increase check interval when healthy (10 → 20 → 30 → 60 min). Reset to 10 min after any anomaly.
- This skill is meant to be automated via CronCreate — do not ask the user whether to set it up. Just set it.

## CronCreate Setup Example

```
After training is confirmed stable:
  CronCreate (recurring, every 10 minutes initially):
    "Run /training-check for wandb run <entity>/<project>/<run_id>"
```

As the check interval increases, delete the old CronCreate job and create a new one with the longer interval.
