---
name: ros2-build
description: Build ROS2 workspaces with colcon, track per-package status, capture unresolved deps, and emit ROS2_BUILD_ARTIFACT.json. Runs on whatever environment has the ROS2 distro installed — host, remote SSH, or a container declared via .aris/container.yaml. Use when frameworks includes ros2.
argument-hint: [workspace-root] [--packages pkg1,pkg2]
allowed-tools: Bash(*), Read, Grep, Glob, Write, Edit
---

# ROS2 Build

Build a ROS2 workspace via `colcon build`, capture per-package outcomes, and emit a structured build report. **Execution environment is user-chosen**: host machine with ROS2 installed, a remote SSH target, or a container declared in `.aris/container.yaml`. If no container contract is present, the skill executes directly on the current environment (assumed to have `/opt/ros/<distro>/setup.bash` sourceable).

## Activation Predicate

Fires when:
- `.aris/project.yaml` has `frameworks` including `ros2` AND `build.system: colcon`
- `package.xml` exists under `src/` (workspace root auto-detected)
- Invocation is explicit: `/ros2-build`

## Workflow

### Step 1: Pre-flight

```
📋 Pre-flight (ROS2 build):
   [ ] 1. Execution path resolved: direct host OR ssh OR container (via .aris/container.yaml if present)
   [ ] 2. container_run.sh --probe → runtime detected
   [ ] 3. build.ros2_distro set in .aris/project.yaml OR /opt/ros/<distro>/ exists on target (humble / iron / jazzy / rolling)
   [ ] 4. src/ directory contains at least one package.xml
   [ ] 5. rosdep keys cached (or --skip-rosdep set)
```

### Step 2: Resolve ROS2 distro + workspace

```bash
# Read user-declared distro from .aris/project.yaml (build.ros2_distro).
# If not set, auto-detect from /opt/ros/<distro>/ on the execution target.
# Supported distros: humble (Ubuntu 22.04 LTS), iron (22.04), jazzy (24.04),
# rolling (development). Author whichever you actually have installed.
DISTRO=$(python3 tools/project_contract.py show | python3 -c "import json,sys; print((json.load(sys.stdin).get('build') or {}).get('ros2_distro',''))")
if [[ -z "$DISTRO" ]]; then
  DISTRO=$(ls /opt/ros/ 2>/dev/null | head -1)
fi
[[ -z "$DISTRO" ]] && { echo "HALT: no ROS2 distro found; set build.ros2_distro in .aris/project.yaml"; exit 1; }
WS_ROOT=$(python3 -c "import os; print(os.path.abspath('.'))")
```

### Step 3: Choose execution path

Pick exactly one path based on what the user has configured:

```bash
if [[ -f .aris/container.yaml ]]; then
  EXEC="bash tools/container_run.sh -- "
  # If the container has no mount for the project, push src/ in first:
  CONTAINER_NAME=$(python3 -c "import yaml; print(yaml.safe_load(open('.aris/container.yaml'))['name'])")
  WORKDIR=$(python3 -c "import yaml; print(yaml.safe_load(open('.aris/container.yaml')).get('workdir','/workspace'))")
  docker exec "$CONTAINER_NAME" mkdir -p "$WORKDIR/src" 2>/dev/null || true
  docker cp ./src/. "$CONTAINER_NAME:$WORKDIR/src/" 2>/dev/null || true
elif [[ -n "${REMOTE_HOST:-}" ]]; then
  # Same SSH-rsync flow as /run-experiment Step 3 Option A, but for ROS2
  EXEC="ssh $REMOTE_HOST "
  rsync -avz --include='src/**' --exclude='build/' --exclude='install/' \
    ./ "$REMOTE_HOST:$REMOTE_WORKDIR/"
else
  EXEC=""  # direct host execution
fi
```

### Step 4: Install deps + build

```bash
$EXEC bash -c "
  set -e
  source /opt/ros/$DISTRO/setup.bash
  rosdep install --from-paths src --ignore-src -r -y 2>&1 | tee rosdep.log || true
  colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release 2>&1 | tee colcon.log
"
BUILD_EXIT=$?
```

### Step 5: Parse colcon output

Colcon emits a summary table:
```
Summary: N packages finished [XY min]
  M packages had warnings
  K packages had errors: pkg1 pkg2
```

Parse into structured records: `{package, status, warnings, errors, build_time_s, unresolved_deps}`.

### Step 6: Emit `ROS2_BUILD_ARTIFACT.json`

```json
{
  "audit_skill": "ros2-build",
  "verdict": "PASS|WARN|FAIL",
  "reason_code": "all_packages_built | warnings_present | package_build_failed | rosdep_unresolved",
  "summary": "12 packages built, 2 warnings, 0 errors in 4 min 12s.",
  "audited_input_hashes": {
    "src/": "sha256:<tree-hash>",
    "package.xml": "sha256:<hash>"
  },
  "trace_path": ".aris/traces/ros2-build/<run-id>/",
  "thread_id": "ros2-build-<timestamp>",
  "reviewer_model": "colcon",
  "reviewer_reasoning": "n/a",
  "generated_at": "2026-04-23T00:00:00Z",
  "details": {
    "ros2_distro": "<as declared in project.yaml or auto-detected>",
    "package_count": 12,
    "packages": [
      {"name": "my_controller", "status": "finished", "warnings": 2, "build_time_s": 15.4},
      {"name": "my_perception", "status": "finished", "warnings": 0, "build_time_s": 8.1}
    ],
    "unresolved_deps": [],
    "total_build_time_s": 252.3
  }
}
```

Verdict:
- `PASS` — all packages finished, 0 errors
- `WARN` — finished but warnings > 0
- `FAIL` — any package errored OR unresolved rosdep keys

## Integration

- **Upstream**: `/run-experiment` Step 0 routes ROS2 projects here before invoking any launch_testing
- **Downstream**: `/ros2-launch-test`, `/ros2-bag-replay`, `/ros2-realtime-audit` consume the install/ directory
- **Audit gate**: `verify_ros2_project.sh` reads this JSON first

## Backfill

```bash
/ros2-build --packages my_controller   # rebuild just one package
```

## Error Modes

| Failure | Fix |
|---|---|
| `rosdep install` fails | Run `rosdep update` once; check `/opt/ros/<distro>/share` present |
| Symbol clashes across packages | Rebuild with `--cmake-clean-cache` |
| Missing dependency `<package>` | Add to `package.xml` `<depend>` block |

## See Also

- `shared-references/build-system-contract.md`
- `skills/ros2-launch-test/SKILL.md`
- `tools/container_run.sh`
- `tools/verify_ros2_project.sh`
