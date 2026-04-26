---
name: cuda-build
description: Build CUDA projects via nvcc + CMake CUDA language with the user-declared GPU architecture (sm_XX from .aris/project.yaml, or `native` as fallback), capture register usage / shared-mem / PTX size, and emit CUDA_BUILD_ARTIFACT.json. Runs wherever nvcc is installed — host, remote SSH target, or a container declared in .aris/container.yaml.
argument-hint: [project-root] [--arch sm_XX]
allowed-tools: Bash(*), Read, Grep, Glob, Write, Edit
---

# CUDA Build

Compile CUDA kernels via nvcc, extract per-kernel register / shared-memory / PTX-size metadata (`--ptxas-options=-v`), and write a structured build report. **Execution environment is user-chosen**: host with `nvcc` in PATH, a remote GPU workstation via SSH, or any container the user declares in `.aris/container.yaml`. ARIS does not ship a container; the name in the user's `.aris/container.yaml` identifies their own environment.

## Activation Predicate

Fires when:
- `.aris/project.yaml` has `frameworks` including `cuda` AND `build.cuda_arch` set
- Any `.cu` or `.cuh` file present (auto-detected)
- Invocation: `/cuda-build [--arch sm_XX]`

## Workflow

### Step 1: Pre-flight

```
📋 Pre-flight:
   [ ] 1. Execution target has /usr/local/cuda/bin/nvcc (host / remote / container per user's config)
   [ ] 2. build.cuda_arch set (user's GPU compute capability, e.g. sm_80, sm_86, sm_89, sm_90)
   [ ] 3. CUDA toolchain in container PATH (pre_exec includes cuda bin)
   [ ] 4. Source tree contains CMakeLists.txt with enable_language(CUDA) OR an explicit Makefile
```

### Step 2: Resolve arch + flags

```bash
# Read the user-declared CUDA arch from .aris/project.yaml build.cuda_arch.
# Fallback to `native` (requires a running GPU at build time) if not set.
# Examples the user may set: sm_70 (V100), sm_75 (T4/RTX20), sm_80 (A100),
# sm_86 (RTX30/A10/A40), sm_89 (RTX40/L4), sm_90 (H100). Pick your hardware.
ARCH=$(python3 tools/project_contract.py show | python3 -c "import json,sys; print((json.load(sys.stdin).get('build') or {}).get('cuda_arch','native'))")
ARCH="${ARCH_FLAG:-$ARCH}"
SM_NUM="${ARCH#sm_}"
if [[ "$ARCH" == "native" ]]; then
  GENCODE="-arch=native"
else
  GENCODE="-gencode arch=compute_${SM_NUM},code=sm_${SM_NUM}"
fi
```

### Step 3: Build (host, remote, or container)

Pick the execution path based on what's configured:

```bash
if [[ -f .aris/container.yaml ]]; then
  EXEC="bash tools/container_run.sh -- "
elif [[ -n "${REMOTE_HOST:-}" ]]; then
  EXEC="ssh $REMOTE_HOST "
else
  EXEC=""   # direct host
fi

$EXEC bash -c "
  export PATH=/usr/local/cuda/bin:\$PATH
  # CMake path
  if [ -f CMakeLists.txt ]; then
    cmake -S . -B build-cuda -DCMAKE_BUILD_TYPE=Release \\
      -DCMAKE_CUDA_ARCHITECTURES=$SM_NUM \\
      -DCMAKE_CUDA_FLAGS='--ptxas-options=-v -lineinfo' 2>&1 | tee cmake-cuda.log
    cmake --build build-cuda -j 2>&1 | tee nvcc.log
  else
    # Makefile path
    NVCC_FLAGS=\"-arch=$ARCH -std=c++17 -O3 --ptxas-options=-v -lineinfo\" make 2>&1 | tee nvcc.log
  fi
"
BUILD_EXIT=${PIPESTATUS[0]}
```

### Step 4: Extract per-kernel metadata

`--ptxas-options=-v` emits lines like:
```
ptxas info    : Compiling entry function '_Z6saxpyfPfPfi' for '<declared-arch>'
ptxas info    : Used 12 registers, 40 bytes cmem[0]
ptxas info    : Function properties for _Z6saxpyfPfPfi
    0 bytes stack frame, 0 bytes spill stores, 0 bytes spill loads
```

Parse into per-kernel records:

```python
import re
kernels = []
cur = None
for line in open("nvcc.log"):
    m = re.search(r"Compiling entry function '([^']+)' for '([^']+)'", line)
    if m:
        if cur: kernels.append(cur)
        cur = {"mangled": m.group(1), "arch": m.group(2), "registers": 0,
               "cmem_bytes": 0, "smem_bytes": 0, "stack_bytes": 0,
               "spill_stores_bytes": 0, "spill_loads_bytes": 0}
        continue
    if cur:
        if m := re.search(r"Used (\d+) registers, (\d+) bytes cmem", line):
            cur["registers"] = int(m.group(1))
            cur["cmem_bytes"] = int(m.group(2))
        if m := re.search(r"Used (\d+) bytes smem", line):
            cur["smem_bytes"] = int(m.group(1))
        if m := re.search(r"(\d+) bytes stack frame, (\d+) bytes spill stores, (\d+) bytes spill loads", line):
            cur["stack_bytes"] = int(m.group(1))
            cur["spill_stores_bytes"] = int(m.group(2))
            cur["spill_loads_bytes"] = int(m.group(3))
if cur: kernels.append(cur)
```

### Step 5: Flag register pressure / spill

Rules:
- `registers > 255` → `FAIL register_overflow`
- `spill_stores_bytes > 0` → `WARN register_spill`
- `smem_bytes > 48KB` → `WARN smem_near_limit` (per-arch max differs — e.g. ~100KB on Ampere/Hopper; consult your arch's programming guide)

### Step 6: Emit `CUDA_BUILD_ARTIFACT.json`

```json
{
  "audit_skill": "cuda-build",
  "verdict": "PASS|WARN|FAIL",
  "reason_code": "build_ok | register_spill | register_overflow | smem_near_limit | build_failed",
  "summary": "Built 4 kernels for sm_XX. Max registers 40, no spill, max smem 16KB.",
  "audited_input_hashes": {
    "src/": "sha256:<tree-hash>",
    "CMakeLists.txt": "sha256:<hash>"
  },
  "trace_path": ".aris/traces/cuda-build/<run-id>/",
  "thread_id": "cuda-build-<timestamp>",
  "reviewer_model": "nvcc+ptxas",
  "reviewer_reasoning": "n/a",
  "generated_at": "2026-04-23T00:00:00Z",
  "details": {
    "cuda_arch": "<as declared in project.yaml>",
    "cuda_version": "<from `nvcc --version`>",
    "kernel_count": 4,
    "kernels": [
      {
        "mangled": "_Z6saxpyfPfPfi",
        "demangled": "saxpy(float, float*, float*, int)",
        "registers": 12,
        "smem_bytes": 0,
        "cmem_bytes": 40,
        "stack_bytes": 0,
        "spill_stores_bytes": 0,
        "spill_loads_bytes": 0
      }
    ],
    "ptx_size_bytes": 4096,
    "compile_time_s": 5.2
  }
}
```

## Integration

- **Upstream**: `/run-experiment` Step 0 routes cuda projects here first
- **Downstream**: `/cuda-sanitize`, `/cuda-profile`, `/cuda-correctness-audit` all read the kernel list from this JSON
- **Audit gate**: `verify_cuda_project.sh` requires PASS or WARN (FAIL blocks)

## Error Modes

| Failure | Fix |
|---|---|
| `nvcc: command not found` | container `pre_exec` missing `export PATH=/usr/local/cuda/bin:$PATH` |
| Register overflow | Split kernel, use `__launch_bounds__`, or reduce ILP |
| Spill stores > 0 | Too many live values; audit shared-memory usage or use smaller tile sizes |
| PTX only, no SASS (cubin) | Missing `-gencode` for target arch; JIT at runtime may fail |

## See Also

- `shared-references/build-system-contract.md`
- `skills/cuda-sanitize/SKILL.md`
- `skills/cuda-profile/SKILL.md`
- `tools/container_run.sh`
