---
name: ros2-realtime-audit
description: Verify real-time claims (p50/p95/p99 latency, control-loop frequency) from rosbag traces or live system. Flags priority inversion, long callbacks, TF lookup errors. Emits ROS2_REALTIME_AUDIT.json; blocks submission on any declared-deadline miss.
argument-hint: [bag-path] [--deadlines .aris/deadlines.yaml]
allowed-tools: Bash(*), Read, Grep, Glob, Write, Edit
---

# ROS2 Real-Time Audit

Any paper claiming "100 Hz control" or "10 ms end-to-end latency" must back the number with a trace where every inter-arrival and every callback duration is measured. This skill turns a rosbag (or live session) into a real-time report with statistical rigor.

## Activation Predicate

Fires when:
- `.aris/project.yaml` has `frameworks` including `ros2` AND `metrics.ros2` includes `control_loop_freq_hz` or `topic_latency_p99_ms`
- Paper body contains numeric latency / frequency claims
- `assurance: submission` set (real-time claim without this audit = FAIL)

## Workflow

### Step 1: Pre-flight

```
📋 Pre-flight:
   [ ] 1. Input bag (or live session) has timestamps with ns resolution
   [ ] 2. Deadlines declared in .aris/deadlines.yaml (topic → p99 budget)
   [ ] 3. Relevant topics identified (cmd_vel, odom, tf, /diagnostics)
```

Deadlines format:
```yaml
deadlines:
  - {topic: /cmd_vel, target_rate_hz: 100, p99_budget_ms: 10, p999_budget_ms: 15}
  - {topic: /odom, target_rate_hz: 50, p99_budget_ms: 20}
  - {callback_group: /controller/timer, p99_budget_ms: 5}
```

### Step 2: Extract inter-arrival times

```python
import rosbag2_py
import numpy as np

msgs = []  # populate from bag
ts = np.array([m[2] for m in msgs])  # ns
dt_ms = np.diff(ts) / 1e6
stats = {
    "count": len(dt_ms),
    "mean_ms": float(np.mean(dt_ms)),
    "median_ms": float(np.median(dt_ms)),
    "p95_ms": float(np.percentile(dt_ms, 95)),
    "p99_ms": float(np.percentile(dt_ms, 99)),
    "p999_ms": float(np.percentile(dt_ms, 99.9)),
    "max_ms": float(np.max(dt_ms)),
    "jitter_stdev_ms": float(np.std(dt_ms)),
}
```

### Step 3: Extract callback durations (live only, requires instrumentation)

If running live with ROS2 tracing (`ros2_tracing` / LTTng) enabled:

```bash
bash tools/container_run.sh -- bash -c "
  ros2 trace start my_session --events ros2:callback_start,ros2:callback_end
  # ... run system ...
  ros2 trace stop my_session
  babeltrace2 ~/.ros/tracing/my_session/ > trace.log
"
```

Parse trace for `callback_start / callback_end` pairs per callback group; compute duration percentiles.

### Step 4: Check TF lookup errors

```bash
grep -iE "TF_OLD_DATA|lookup transform|ExtrapolationException" rosout.log > tf-errors.log
```

### Step 5: Priority inversion detector

Callback duration > 2× target period indicates potential priority inversion when mixed with higher-priority callbacks in the same executor:

```python
for topic in stats:
    target_period_ms = 1000 / deadlines[topic]["target_rate_hz"]
    if stats[topic]["p99_ms"] > 2 * target_period_ms:
        findings.append({"topic": topic, "type": "priority_inversion_suspect"})
```

### Step 6: Emit `ROS2_REALTIME_AUDIT.json`

```json
{
  "audit_skill": "ros2-realtime-audit",
  "verdict": "PASS|WARN|FAIL|NOT_APPLICABLE",
  "reason_code": "within_budget | budget_exceeded | deadline_missed | tf_errors_present | priority_inversion_suspected",
  "summary": "3 topics audited. /cmd_vel: 99.8Hz observed, p99 8.2ms (budget 10ms) PASS.",
  "audited_input_hashes": {"input-bag/metadata.yaml": "sha256:<hash>"},
  "trace_path": ".aris/traces/ros2-realtime-audit/<run-id>/",
  "thread_id": "ros2-realtime-audit-<timestamp>",
  "reviewer_model": "rosbag2+numpy",
  "reviewer_reasoning": "n/a",
  "generated_at": "2026-04-23T00:00:00Z",
  "details": {
    "topics": [
      {
        "topic": "/cmd_vel",
        "observed_rate_hz": 99.8,
        "target_rate_hz": 100,
        "p50_ms": 10.02,
        "p95_ms": 10.4,
        "p99_ms": 8.2,
        "p999_ms": 12.1,
        "max_ms": 18.3,
        "budget_ms": 10,
        "within_budget": true
      }
    ],
    "deadline_misses": [],
    "tf_errors_count": 0,
    "priority_inversion_suspects": [],
    "callback_durations": []
  }
}
```

Verdict:
- `PASS` — all topics within p99 budget AND no TF errors
- `WARN` — within p99 but p999 or max exceeds 2× budget (report but don't block draft)
- `FAIL` — any declared deadline missed OR TF errors present at submission
- `NOT_APPLICABLE` — no real-time claims in paper

### Step 7: Blocking

At `assurance: submission`, `verify_paper_audits.sh` treats `verdict != PASS` as blocker when `venue_family: robotics`.

## Integration

- **Upstream**: `/ros2-launch-test` records the bag this skill reads
- **Downstream**: `/paper-claim-audit` Phase C.5 cross-checks paper-stated latencies against this audit's percentiles
- **Audit gate**: `tools/verify_ros2_project.sh`

## Known Failure Patterns (research-wiki/failures/)

- `ros2-callback-group-deadlock` — long-running callback blocks its group, other callbacks starve
- `ros2-tf-tree-race` — TF_OLD_DATA from publish-after-lookup
- `ros2-dds-discovery-failure` — DDS discovery storm causes jitter spikes during startup

## See Also

- `shared-references/build-system-contract.md`
- `skills/ros2-launch-test/SKILL.md`
- `skills/paper-claim-audit/SKILL.md`
- `tools/verify_ros2_project.sh`
