---
name: ros2-launch-test
description: Wrap ROS2 launch_testing to verify node discovery, topic rate, QoS match, TF tree completeness, and real-time deadlines. Emits ROS2_LAUNCH_TEST_AUDIT.json; blocks submission on any QoS mismatch or deadline miss.
argument-hint: [launch-file.py] [--timeout 60]
allowed-tools: Bash(*), Read, Grep, Glob, Write, Edit
---

# ROS2 Launch Test

Validate a ROS2 system at runtime via `launch_testing`: bring up nodes, verify discovery, assert topic rates and QoS profiles, and check TF tree completeness. Runs wherever ROS2 is installed — host, remote SSH target, or a container declared in `.aris/container.yaml`. Without a container contract the skill executes directly on the current environment.

## Activation Predicate

Fires when:
- `.aris/project.yaml` has `frameworks` including `ros2` AND `assurance ∈ {draft, submission}`
- A `launch/*.py` or `launch/*.yaml` exists
- Invocation: `/ros2-launch-test <launch-file>`

## Why This Exists

ROS2 "it launches" ≠ "it works correctly". Silent QoS mismatches (RELIABLE publisher ↔ BEST_EFFORT subscriber) produce dropped messages that look like hardware problems. TF tree gaps produce late lookups. Deadline misses surface only under load. `launch_testing` is the ROS2-native framework for asserting these at integration time.

## Workflow

### Step 1: Pre-flight

```
📋 Pre-flight:
   [ ] 1. ROS2_BUILD_ARTIFACT.json PASS
   [ ] 2. install/setup.bash present inside container
   [ ] 3. Launch file syntactically valid (ros2 launch --help parses)
   [ ] 4. Expected nodes + topics declared in .aris/ros2-expectations.yaml (or --expected-nodes/--expected-topics flags)
```

Expectations file format:
```yaml
nodes:
  - /controller
  - /perception
topics:
  - name: /cmd_vel
    type: geometry_msgs/Twist
    rate_hz: 100
    qos: {reliability: RELIABLE, history: KEEP_LAST, depth: 10}
tf_frames:
  - [map, odom]
  - [odom, base_link]
deadlines:
  - {topic: /cmd_vel, p99_ms: 10}
```

### Step 2: Author a launch_testing harness

Generate `test_launch.py` if absent:

```python
import launch
import launch_testing.actions
import pytest
from launch_ros.actions import Node

def generate_test_description():
    return launch.LaunchDescription([
        Node(package='my_package', executable='controller'),
        Node(package='my_package', executable='perception'),
        launch_testing.actions.ReadyToTest(),
    ])

class TestSystem:
    def test_nodes_discovered(self, proc_output):
        # Wait up to 10s for /controller and /perception
        pass

    def test_cmd_vel_rate(self, proc_output):
        # Subscribe for 5s, assert rate ≥ 95 Hz
        pass

    def test_qos_match(self, proc_output):
        # Query QoS on /cmd_vel pub/sub, assert RELIABLE match
        pass

    def test_tf_tree_complete(self, proc_output):
        # /tf_static + /tf contain map→odom and odom→base_link
        pass
```

### Step 3: Run launch_testing

```bash
bash tools/container_run.sh -- bash -c "
  source /opt/ros/$DISTRO/setup.bash    # $DISTRO from project_contract.py or auto-detect
  source install/setup.bash
  cd test/
  pytest --launch-testing test_launch.py -v --junitxml=launch-test-results.xml 2>&1 | tee launch-test.log
"
```

### Step 4: Record rosbag during the test

For later replay + regression analysis:

```bash
bash tools/container_run.sh -- bash -c "
  source install/setup.bash
  ros2 bag record -a -o /tmp/launch-bag &
  BAG_PID=\$!
  sleep 30
  kill \$BAG_PID
"
docker cp "$CONTAINER_NAME:/tmp/launch-bag" ./launch-bag
```

### Step 5: Parse results into structured findings

Parse `launch-test-results.xml` (JUnit) + ros2 topic / rate / tf outputs (live-captured during Step 3).

### Step 6: Emit `ROS2_LAUNCH_TEST_AUDIT.json`

```json
{
  "audit_skill": "ros2-launch-test",
  "verdict": "PASS|FAIL|NOT_APPLICABLE",
  "reason_code": "all_assertions_passed | nodes_not_discovered | rate_below_spec | qos_mismatch | tf_gap | deadline_missed",
  "summary": "4 assertions: all PASS. Discovery 0.8s, rate 99.8Hz, QoS match, TF complete.",
  "audited_input_hashes": {
    "launch/main.py": "sha256:<hash>",
    "install/setup.bash": "sha256:<hash>"
  },
  "trace_path": ".aris/traces/ros2-launch-test/<run-id>/",
  "thread_id": "ros2-launch-test-<timestamp>",
  "reviewer_model": "ros2-launch-testing",
  "reviewer_reasoning": "n/a",
  "generated_at": "2026-04-23T00:00:00Z",
  "details": {
    "ros2_distro": "<as declared in project.yaml or auto-detected>",
    "nodes_discovered": ["/controller", "/perception"],
    "nodes_missing": [],
    "topic_rates": [
      {"topic": "/cmd_vel", "observed_hz": 99.8, "expected_hz": 100, "pass": true}
    ],
    "qos_checks": [
      {"topic": "/cmd_vel", "pub_reliability": "RELIABLE", "sub_reliability": "RELIABLE", "match": true}
    ],
    "tf_checks": [{"parent": "map", "child": "odom", "ok": true}],
    "deadline_misses": [],
    "bag_path": "./launch-bag"
  }
}
```

Verdict:
- `PASS` — all four check classes pass
- `FAIL` — any assertion fails (node missing, rate low, QoS mismatch, TF gap, deadline miss)
- `NOT_APPLICABLE` — no launch files present (skip gracefully)

### Step 7: Blocking behavior

At `assurance: submission` with `venue_family: robotics`, `verify_paper_audits.sh` treats `verdict != PASS` as exit 1 blocker.

## Integration

- **Upstream**: `/ros2-build` produces install/
- **Downstream**: `/ros2-bag-replay` uses the recorded bag; `/ros2-realtime-audit` reads topic rates + deadlines
- **Audit gate**: `tools/verify_ros2_project.sh`

## Known Failure Patterns (research-wiki/failures/)

- `ros2-qos-profile-mismatch` — RELIABLE pub + BEST_EFFORT sub silently drops messages
- `ros2-callback-group-deadlock` — mutually exclusive callback groups with circular service calls
- `ros2-tf-tree-race` — `tf_static` published after the first lookup, causing intermittent TF_OLD_DATA

## See Also

- `shared-references/build-system-contract.md`
- `skills/ros2-bag-replay/SKILL.md`
- `skills/ros2-realtime-audit/SKILL.md`
- `tools/container_run.sh`
