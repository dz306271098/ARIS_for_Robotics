---
name: cuda-sanitize
description: Run compute-sanitizer (memcheck/racecheck/synccheck/initcheck) against CUDA kernels, parse findings, and emit CUDA_SANITIZER_AUDIT.json. Blocks assurance=submission on any violation.
argument-hint: [kernel-binary] [--tool memcheck|racecheck|synccheck|initcheck|all]
allowed-tools: Bash(*), Read, Grep, Glob, Write, Edit
---

# CUDA Sanitizer Audit

Runtime correctness gate for CUDA kernels. `compute-sanitizer` is the GPU counterpart of ASan/TSan; silent misuse (uninitialized shared, global-memory races, barrier violations) produces wrong outputs without crashing. This skill runs all four tools and fails fast on any finding. Runs wherever `compute-sanitizer` is in PATH — host, remote, or a container declared in `.aris/container.yaml`.

## Activation Predicate

Fires when:
- `.aris/project.yaml` has `frameworks` including `cuda` AND `sanitizers.gpu` non-empty
- CUDA_BUILD_ARTIFACT.json present AND PASS
- `assurance ∈ {draft, submission}` (always runs at submission; opt-in at draft)

## Workflow

### Step 1: Pre-flight

```
📋 Pre-flight:
   [ ] 1. CUDA_BUILD_ARTIFACT.json PASS
   [ ] 2. Binary identified (exe OR test binary exercising the kernels)
   [ ] 3. Tool list resolved (default: memcheck racecheck synccheck initcheck)
   [ ] 4. Runtime GPU driver functional (compute-sanitizer --tool=memcheck --launch-count=0 probe)
   [ ] 5. Skip gracefully with NOT_APPLICABLE if driver unavailable
```

### Step 2: Resolve tool list

```bash
TOOLS=$(python3 - <<'PY'
import json, subprocess
cfg = json.loads(subprocess.check_output(["python3","tools/project_contract.py","show"]).decode())
print(" ".join((cfg.get("sanitizers") or {}).get("gpu", [])))
PY
)
TOOLS="${TOOL_FLAG:-${TOOLS:-memcheck racecheck synccheck initcheck}}"
```

Note: `racecheck`, `synccheck`, and `initcheck` are mutually exclusive with each other (shared instrumentation) and with `memcheck`. Iterate one at a time.

### Step 3: Driver availability probe

```bash
PROBE=$(bash tools/container_run.sh -- bash -c "/usr/local/cuda/bin/compute-sanitizer --version 2>&1 | head -3")
if ! bash tools/container_run.sh -- bash -c "echo 'int main(){return 0;}' | /usr/local/cuda/bin/nvcc -x cu - -o /tmp/probe && /tmp/probe; echo \$?" >/dev/null 2>&1; then
  # Driver unavailable — emit NOT_APPLICABLE and skip
  VERDICT=NOT_APPLICABLE
  REASON=driver_unavailable
fi
```

### Step 4: Run each tool

```bash
for TOOL in $TOOLS; do
  bash tools/container_run.sh -- bash -c "
    /usr/local/cuda/bin/compute-sanitizer --tool=$TOOL --print-limit 50 \\
      --log-file /tmp/sanitizer-$TOOL.log \\
      --xml-file /tmp/sanitizer-$TOOL.xml \\
      ./build-cuda/kernel_test
  " || true
  docker cp "$CONTAINER_NAME:/tmp/sanitizer-$TOOL.log" ".aris/traces/cuda-sanitize/$RUN_ID/" 2>/dev/null || true
done
```

### Step 5: Parse findings

compute-sanitizer XML has a stable schema:
```xml
<report>
  <check>
    <kind>ERROR</kind>
    <message>Invalid __global__ write of size 4</message>
    <location>/path/kernel.cu:42</location>
    <backtrace>...</backtrace>
  </check>
</report>
```

Parse into `{tool, kind, message, file, line, backtrace}` records.

### Step 6: Emit `CUDA_SANITIZER_AUDIT.json`

```json
{
  "audit_skill": "cuda-sanitize",
  "verdict": "PASS|FAIL|NOT_APPLICABLE",
  "reason_code": "clean | findings_present | driver_unavailable | no_gpu_sanitizers_configured",
  "summary": "4 tools run. memcheck: 0, racecheck: 0, synccheck: 0, initcheck: 0.",
  "audited_input_hashes": {
    "build-cuda/kernel_test": "sha256:<hash>",
    "src/": "sha256:<tree-hash>"
  },
  "trace_path": ".aris/traces/cuda-sanitize/<run-id>/",
  "thread_id": "cuda-sanitize-<timestamp>",
  "reviewer_model": "compute-sanitizer",
  "reviewer_reasoning": "n/a",
  "generated_at": "2026-04-23T00:00:00Z",
  "details": {
    "tools_run": ["memcheck", "racecheck", "synccheck", "initcheck"],
    "findings_by_tool": {
      "memcheck": 0,
      "racecheck": 0,
      "synccheck": 0,
      "initcheck": 0
    },
    "findings": [],
    "driver_available": true,
    "total_runtime_s": 42.1
  }
}
```

Verdict:
- `PASS` — all tools 0 findings
- `FAIL` — any finding
- `NOT_APPLICABLE` — driver unavailable OR no sanitizers configured (still flagged as missing evidence at submission)

### Step 7: Blocking

At `assurance: submission`, `verify_paper_audits.sh` treats `verdict != PASS` as blocker when `frameworks` includes `cuda`.

## Integration

- **Upstream**: `/cuda-build` produces test binaries
- **Downstream**: `/cuda-profile` — do NOT run profile under sanitizer (overhead distorts timing)
- **Audit gate**: `tools/verify_cuda_project.sh`

## Known Failure Patterns (research-wiki/failures/)

- `cuda-async-copy-race` — `cudaMemcpyAsync` without matching event / stream sync → racecheck finding
- `cuda-unaligned-global-access` → memcheck `Invalid __global__ read/write`
- `cuda-shared-memory-bank-conflict` → racecheck reports bank-conflict warnings

## See Also

- `shared-references/build-system-contract.md`
- `skills/cuda-build/SKILL.md`
- `skills/cuda-profile/SKILL.md`
- `tools/verify_cuda_project.sh`
