---
name: cpp-build
description: Build C++ projects via the detected build system (CMake / Make / custom) with pinned flags, capture compiler warnings as structured signals, and emit BUILD_ARTIFACT.json for downstream skills. Use when the project contract has language=cpp and a build phase is required.
argument-hint: [project-root]
allowed-tools: Bash(*), Read, Grep, Glob, Write, Edit
---

# C++ Build

Build C++ project at $ARGUMENTS (default: cwd) through the build-system contract, capture warnings and binary artifacts, and write a machine-readable build report.

## Activation Predicate

Fires when any of:
- `.aris/project.yaml` has `language: cpp` or `frameworks` includes `cuda`
- Invocation is explicit: `/cpp-build <dir>`
- Auto-detection sees `CMakeLists.txt` or `Makefile` (no ROS2 `package.xml` — use `/ros2-build` for ROS2 workspaces)

## Workflow

### Step 1: Pre-flight (build-system contract)

```bash
📋 Pre-flight:
   [ ] 1. project_contract.py validate → exit 0
   [ ] 2. Detected build system ∈ {make, cmake}
   [ ] 3. Build directory is clean OR --incremental flag set
   [ ] 4. Compiler + flags determined (print for visibility)
   [ ] HALT if any row above fails
```

```bash
python3 tools/project_contract.py validate || { echo "HALT: invalid contract"; exit 1; }
BUILD_CMD=$(python3 tools/project_contract.py get-build-cmd)
LANG=$(python3 tools/project_contract.py get-language)
FRAMEWORKS=$(python3 tools/project_contract.py get-frameworks)
```

### Step 2: Execute build

If `cuda` in frameworks, dispatch through container (runtime `nvcc` requires container toolchain):

```bash
if echo "$FRAMEWORKS" | grep -qw cuda; then
  bash tools/container_run.sh -- bash -c "$BUILD_CMD 2>&1 | tee BUILD.log"
else
  bash -c "$BUILD_CMD 2>&1 | tee BUILD.log"
fi
BUILD_EXIT=${PIPESTATUS[0]}
```

### Step 3: Parse warnings + binary metadata

```bash
WARN_COUNT=$(grep -cE "warning:" BUILD.log || echo 0)
ERROR_COUNT=$(grep -cE "error:" BUILD.log || echo 0)
BINARY_SIZE=$(du -sb build/ 2>/dev/null | awk '{print $1}' | head -1)
COMPILE_TIME_S=$(awk '/real/ {print $2}' BUILD.log | tail -1)
```

### Step 4: Emit `BUILD_ARTIFACT.json` (10-field assurance schema)

```json
{
  "audit_skill": "cpp-build",
  "verdict": "PASS|FAIL|WARN",
  "reason_code": "build_ok | build_failed | warnings_over_threshold | linker_error",
  "summary": "Built X binaries, N warnings, 0 errors in 12.3s.",
  "audited_input_hashes": {
    "CMakeLists.txt": "sha256:<hash>",
    "src/": "sha256:<tree-hash>"
  },
  "trace_path": ".aris/traces/cpp-build/<run-id>/",
  "thread_id": "cpp-build-<timestamp>",
  "reviewer_model": "local-compiler",
  "reviewer_reasoning": "n/a",
  "generated_at": "2026-04-23T00:00:00Z",
  "details": {
    "build_system": "cmake",
    "compiler": "g++ 13.2.0",
    "flags": ["-O3", "-DNDEBUG"],
    "warning_count": 3,
    "error_count": 0,
    "binary_size_bytes": 1048576,
    "compile_time_s": 12.3,
    "exit_code": 0,
    "warnings": [
      {"file": "src/a.cpp", "line": 42, "text": "unused variable 'x'"}
    ]
  }
}
```

Verdict mapping:
- `PASS` — `error_count == 0`, `warning_count ≤ threshold` (default 10)
- `WARN` — `error_count == 0`, `warning_count > threshold`
- `FAIL` — `error_count > 0` or non-zero build exit code

### Step 5: Record trace

Write `BUILD.log`, full warning list, and the invocation record under `trace_path`:

```
.aris/traces/cpp-build/<run-id>/
  BUILD.log
  invocation.json
  warnings.jsonl
```

## Integration

- **Upstream**: `/run-experiment` Step 0 (polyglot dispatch) routes here when `LANG=cpp`.
- **Downstream**: `/cpp-sanitize`, `/cpp-bench`, `/cpp-profile` all consume `BUILD_ARTIFACT.json` to locate binaries.
- **Audit gate**: `verify_cpp_project.sh` reads `BUILD_ARTIFACT.json` and blocks `assurance: submission` if `verdict ∈ {FAIL}`.

## Backfill / Repair

If the skill was silently skipped:
```bash
python3 tools/project_contract.py show    # confirm contract
bash tools/container_run.sh --probe       # if cuda
/cpp-build                                # rerun
```

If compilation itself is broken, fix the source, commit, re-run `/cpp-build` — do NOT edit `BUILD_ARTIFACT.json` by hand.

## Error Modes

| Failure | Root cause | Fix |
|--------|------------|-----|
| "HALT: invalid contract" | `.aris/project.yaml` schema error | `project_contract.py init --overwrite` |
| Linker error | Missing `target_link_libraries()` | Fix CMakeLists.txt |
| Warnings explode | `-Werror` not respected by new TU | Audit recent diff, suppress or fix |

## See Also

- `shared-references/build-system-contract.md` — activation predicate + schema
- `shared-references/assurance-contract.md` — 10-field audit JSON template
- `skills/cpp-sanitize/SKILL.md` — consumes built binaries
- `tools/verify_cpp_project.sh` — external verifier
