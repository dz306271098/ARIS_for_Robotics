---
name: cuda-correctness-audit
description: Numerical-equivalence audit of CUDA kernel output vs CPU reference — max absolute difference, relative error, ulp distance, bitwise hash. Catches races, uninit shared, unaligned access that don't always crash. Emits CUDA_CORRECTNESS_AUDIT.json.
argument-hint: [kernel-binary] [--reference <cpu-binary>] [--tolerance abs:1e-5,rel:1e-4,ulp:4]
allowed-tools: Bash(*), Read, Grep, Glob, Write, Edit
---

# CUDA Correctness Audit

A CUDA kernel can produce *plausible-looking* output that's actually wrong — a race produces non-deterministic but bounded values; uninit shared gives quasi-random noise; unaligned accesses merely slow things down but return truncated values. `compute-sanitizer` catches some but not all of these. The definitive check is comparing kernel output against a CPU reference implementation. Runs wherever GPU + CPU reference binaries can execute — host, remote, or a container declared in `.aris/container.yaml`.

## Activation Predicate

Fires when:
- `.aris/project.yaml` has `frameworks` including `cuda`
- A CPU reference implementation exists (same signature; declared in `.aris/cuda-references.yaml`)
- `assurance ∈ {draft, submission}`

## Workflow

### Step 1: Pre-flight

```
📋 Pre-flight:
   [ ] 1. CUDA_BUILD_ARTIFACT.json PASS
   [ ] 2. CPU reference binary / function identified
   [ ] 3. Tolerance declared (abs/rel/ulp)
   [ ] 4. Input generator deterministic (seeded RNG)
```

References manifest:
```yaml
references:
  - kernel: saxpy
    cpu_ref: ./build/saxpy_cpu
    tolerance:
      abs: 1.0e-5
      rel: 1.0e-4
      ulp: 4
  - kernel: gemm_fp16
    cpu_ref: ./build/gemm_fp32_cpu  # higher precision reference
    tolerance:
      abs: 5.0e-3
      rel: 1.0e-2
      ulp: 2048  # FP16 vs FP32 intrinsic gap
```

### Step 2: Run GPU + CPU on identical inputs

```bash
bash tools/container_run.sh -- bash -c "
  set -e
  # Deterministic input: same seed on both
  ./build-cuda/saxpy --seed 42 --n 1048576 --output /tmp/gpu-output.bin
  ./build/saxpy_cpu --seed 42 --n 1048576 --output /tmp/cpu-output.bin
"
docker cp "$CONTAINER_NAME:/tmp/gpu-output.bin" .aris/traces/cuda-correctness-audit/
docker cp "$CONTAINER_NAME:/tmp/cpu-output.bin" .aris/traces/cuda-correctness-audit/
```

### Step 3: Compare

```python
import numpy as np
import struct

gpu = np.fromfile(".aris/traces/cuda-correctness-audit/gpu-output.bin", dtype=np.float32)
cpu = np.fromfile(".aris/traces/cuda-correctness-audit/cpu-output.bin", dtype=np.float32)

abs_diff = np.abs(gpu - cpu)
max_abs = float(abs_diff.max())
rel_diff = abs_diff / (np.abs(cpu) + 1e-12)
max_rel = float(rel_diff.max())

# ulp distance (float32)
def ulp_distance(a, b):
    a_int = a.view(np.int32)
    b_int = b.view(np.int32)
    # handle sign
    a_int = np.where(a_int < 0, np.int32(0x80000000) - a_int, a_int)
    b_int = np.where(b_int < 0, np.int32(0x80000000) - b_int, b_int)
    return np.abs(a_int - b_int)
max_ulp = int(ulp_distance(gpu.astype(np.float32), cpu.astype(np.float32)).max())
```

### Step 4: Determinism check (multiple GPU runs)

If the kernel should be deterministic (no atomics without ordering, no `__shfl_down_sync` races):

```bash
for i in 1 2 3; do
  bash tools/container_run.sh -- bash -c "./build-cuda/saxpy --seed 42 --output /tmp/gpu-$i.bin"
done
# Compare gpu-1 vs gpu-2 vs gpu-3 — must be bitwise identical
```

### Step 5: Emit `CUDA_CORRECTNESS_AUDIT.json`

```json
{
  "audit_skill": "cuda-correctness-audit",
  "verdict": "PASS|FAIL|NOT_APPLICABLE",
  "reason_code": "within_tolerance | tolerance_exceeded | nondeterministic | cpu_ref_missing | driver_unavailable",
  "summary": "saxpy: max abs 3.2e-6, rel 1.1e-5, ulp 1. Deterministic across 3 runs. PASS.",
  "audited_input_hashes": {
    "build-cuda/saxpy": "sha256:<hash>",
    "build/saxpy_cpu": "sha256:<hash>"
  },
  "trace_path": ".aris/traces/cuda-correctness-audit/<run-id>/",
  "thread_id": "cuda-correctness-audit-<timestamp>",
  "reviewer_model": "numpy+bitwise",
  "reviewer_reasoning": "n/a",
  "generated_at": "2026-04-23T00:00:00Z",
  "details": {
    "per_kernel": [
      {
        "kernel": "saxpy",
        "elements_compared": 1048576,
        "max_abs_diff": 3.2e-6,
        "max_rel_diff": 1.1e-5,
        "max_ulp_distance": 1,
        "tolerance": {"abs": 1e-5, "rel": 1e-4, "ulp": 4},
        "within_tolerance": true,
        "deterministic": true,
        "cpu_reference_sha256": "sha256:<hash>",
        "gpu_output_sha256": "sha256:<hash>"
      }
    ],
    "overall_pass": true
  }
}
```

Verdict:
- `PASS` — all kernels within tolerance AND deterministic (when determinism asserted)
- `FAIL` — any kernel exceeds tolerance OR nondeterministic when should be
- `NOT_APPLICABLE` — no CPU reference declared OR driver unavailable

### Step 6: Blocking

At `assurance: submission`, `verify_paper_audits.sh` treats `verdict != PASS` as blocker when `frameworks` includes `cuda`.

## Integration

- **Upstream**: `/cuda-build`, `/cuda-sanitize`
- **Downstream**: `/paper-claim-audit` Phase C.6 — quantitative accuracy claims must reference this audit
- **Audit gate**: `tools/verify_cuda_project.sh`

## Known Failure Patterns (research-wiki/failures/)

- `cuda-async-copy-race` — wrong results only on some runs; flagged by determinism check
- `cuda-unaligned-global-access` — truncated reads at misaligned offsets
- `cuda-register-pressure-spill` — can produce wrong results if spill slots are uninit

## See Also

- `skills/cuda-sanitize/SKILL.md` — complementary runtime check
- `skills/cuda-profile/SKILL.md`
- `shared-references/build-system-contract.md`
