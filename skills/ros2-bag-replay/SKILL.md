---
name: ros2-bag-replay
description: Deterministic rosbag2 replay + golden-output comparison. Captures topic-by-topic diff between a fresh run and a reference bag; emits ROS2_BAG_REPLAY_AUDIT.json. Use to verify reproducibility of robotics claims or detect regressions.
argument-hint: [bag-path] [--golden path/to/reference-bag] [--topics /cmd_vel,/odom]
allowed-tools: Bash(*), Read, Grep, Glob, Write, Edit
---

# ROS2 Bag Replay

Replay a rosbag2 file against the current nodes and compare outputs topic-by-topic against a reference ("golden") bag. This makes robotics reproducibility a first-class gate, not an executor's memory of "last Tuesday it worked".

## Activation Predicate

Fires when:
- `.aris/project.yaml` has `frameworks` including `ros2` AND `bench.harness: rosbag-replay`
- Invocation: `/ros2-bag-replay <bag> --golden <golden-bag>`
- Triggered automatically by `/run-experiment` when a bag claim is present in a paper section

## Workflow

### Step 1: Pre-flight

```
📋 Pre-flight:
   [ ] 1. ROS2_BUILD_ARTIFACT.json PASS
   [ ] 2. Input bag exists, is readable, has metadata.yaml
   [ ] 3. Golden bag exists (if comparison mode)
   [ ] 4. Topic list resolved (default: all topics present in input bag)
```

### Step 2: Replay (host, remote, or container)

Choose the execution target the same way as `/ros2-build` Step 3: container if `.aris/container.yaml` exists, remote if `REMOTE_HOST` is set, otherwise host.

```bash
$EXEC bash -c "
  source /opt/ros/$DISTRO/setup.bash    # $DISTRO from project_contract.py or auto-detect
  source install/setup.bash
  # Launch nodes under test in background
  ros2 launch my_package main.launch.py &
  LAUNCH_PID=\$!
  sleep 2   # let nodes discover

  # Record outputs while replaying input
  ros2 bag record -a -o /tmp/replay-output &
  RECORD_PID=\$!

  ros2 bag play /tmp/input-bag --rate 1.0 --clock
  kill \$RECORD_PID \$LAUNCH_PID
  wait
"
docker cp "$CONTAINER_NAME:/tmp/replay-output" ./replay-output
```

### Step 3: Topic-by-topic comparison

Extract per-topic messages from both bags, align by timestamp, and compute diffs:

```python
import rosbag2_py
import numpy as np

def extract(bag_path, topic):
    reader = rosbag2_py.SequentialReader()
    reader.open(rosbag2_py.StorageOptions(uri=bag_path, storage_id='sqlite3'),
                rosbag2_py.ConverterOptions())
    reader.set_filter(rosbag2_py.StorageFilter(topics=[topic]))
    msgs = []
    while reader.has_next():
        t, data, ts = reader.read_next()
        msgs.append((ts, data))
    return msgs

# Align by timestamp, compute field-wise absdiff, max, p99
```

For numeric topics (Float / Twist / Pose): L_∞ + L_2 norms. For image topics: PSNR / SSIM. For custom types: declared comparator in `.aris/bag-comparators.yaml` (default: binary-exact).

### Step 4: Emit `ROS2_BAG_REPLAY_AUDIT.json`

```json
{
  "audit_skill": "ros2-bag-replay",
  "verdict": "PASS|FAIL|NOT_APPLICABLE",
  "reason_code": "bag_match | per_topic_divergence | bag_missing | comparator_undefined",
  "summary": "Replayed 12,340 messages across 5 topics. 4 match exactly, 1 within tolerance.",
  "audited_input_hashes": {
    "input-bag/metadata.yaml": "sha256:<hash>",
    "golden-bag/metadata.yaml": "sha256:<hash>"
  },
  "trace_path": ".aris/traces/ros2-bag-replay/<run-id>/",
  "thread_id": "ros2-bag-replay-<timestamp>",
  "reviewer_model": "rosbag2",
  "reviewer_reasoning": "n/a",
  "generated_at": "2026-04-23T00:00:00Z",
  "details": {
    "input_message_count": 12340,
    "replay_duration_s": 45.2,
    "per_topic": [
      {"topic": "/cmd_vel", "compared": 4512, "max_abs_diff": 0.001, "l2_norm": 0.012, "pass": true},
      {"topic": "/odom", "compared": 4500, "max_abs_diff": 0.0005, "l2_norm": 0.003, "pass": true}
    ],
    "divergent_topics": []
  }
}
```

Verdict:
- `PASS` — all topics match within declared tolerance
- `FAIL` — any topic exceeds tolerance
- `NOT_APPLICABLE` — no golden bag provided (diagnostic mode, not a gate)

## Integration

- **Upstream**: `/ros2-launch-test` may produce the input bag
- **Downstream**: `/result-to-claim` cites replay accuracy as evidence
- **Audit gate**: `tools/verify_ros2_project.sh`

## Error Modes

| Failure | Fix |
|---|---|
| Bag storage format mismatch (sqlite3 vs mcap) | Convert with `ros2 bag convert` |
| Timestamp skew across bags | Align by message index instead; disclose in report |
| Custom msg types unknown | Source the workspace `install/setup.bash` before replay |

## See Also

- `shared-references/build-system-contract.md`
- `skills/ros2-launch-test/SKILL.md`
- `tools/container_run.sh`
