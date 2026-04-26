---
name: cuda-profile
description: Profile CUDA kernels with Nsight Compute (ncu) per-kernel metrics and Nsight Systems (nsys) session-wide timeline. Extracts occupancy, warp efficiency, memory throughput, SM utilization. Emits CUDA_PROFILE_REPORT.json with roofline-model placement.
argument-hint: [binary-path] [--tool ncu|nsys|both]
allowed-tools: Bash(*), Read, Grep, Glob, Write, Edit
---

# CUDA Profile

Per-kernel micro-architectural profiling for CUDA. Nsight Compute gives you occupancy / warp efficiency / memory throughput per kernel; Nsight Systems shows host-device overlap and kernel-launch overhead. Runs wherever `ncu` / `nsys` are installed — host, remote, or a container declared in `.aris/container.yaml`.

## Activation Predicate

Fires when:
- `.aris/project.yaml` has `frameworks` including `cuda` AND `profile.gpu_tool ∈ {nsight-compute, nsight-systems, nvprof}`
- `/cuda-bench` regression detected OR paper cites kernel-level metrics
- Invocation: `/cuda-profile [binary] [--tool ncu|nsys]`

## Workflow

### Step 1: Pre-flight

```
📋 Pre-flight:
   [ ] 1. CUDA_BUILD_ARTIFACT.json PASS with -lineinfo (for source-level attribution)
   [ ] 2. CUDA_SANITIZER_AUDIT.json PASS (avoid profiling buggy kernels)
   [ ] 3. ncu or nsys available (container has both at /usr/local/cuda/bin)
   [ ] 4. GPU driver functional (profiling needs runtime GPU)
```

### Step 2: Nsight Compute per-kernel (ncu)

```bash
bash tools/container_run.sh -- bash -c "
  /usr/local/cuda/bin/ncu --set full \\
    --target-processes all \\
    --export .aris/traces/cuda-profile/\$(date +%s)/ncu-report \\
    --force-overwrite \\
    ./build-cuda/bench
  /usr/local/cuda/bin/ncu --import .aris/traces/cuda-profile/\$(date +%s)/ncu-report.ncu-rep \\
    --csv --page details > ncu-details.csv
"
```

Key metrics extracted per kernel:
- `sm__throughput.avg.pct_of_peak_sustained_elapsed` — SM utilization
- `sm__warps_active.avg.pct_of_peak_sustained_active` — achieved occupancy
- `smsp__average_warps_issue_stalled_membar_per_issue_active` — memory stalls
- `l1tex__t_bytes.sum` — L1 throughput
- `lts__t_bytes.sum` — L2 throughput
- `dram__bytes.sum` — DRAM throughput
- `sm__warp_cycles_per_issued_inst.avg` — instruction latency

### Step 3: Nsight Systems session-wide (nsys)

```bash
bash tools/container_run.sh -- bash -c "
  /usr/local/cuda/bin/nsys profile -o .aris/traces/cuda-profile/\$(date +%s)/nsys-report \\
    --trace cuda,nvtx,osrt \\
    --stats true \\
    ./build-cuda/bench
"
```

Captures: kernel launch overhead, cuStream events, host-device memcpy overlap, idle gaps.

### Step 4: Roofline-model placement

For each kernel, compute arithmetic intensity (ops / byte) and achieved throughput, place on the roofline:

```python
for k in kernels:
    ops = k["flops"]
    bytes_moved = k["dram_bytes"] + k["l2_bytes"]
    intensity = ops / bytes_moved if bytes_moved else float("inf")
    peak_compute = 19500   # GFLOPS for sm_86 at FP32 (replace per arch)
    peak_mem = 760         # GB/s DRAM
    bound = min(peak_compute, peak_mem * intensity)
    k["roofline"] = {
        "intensity_flop_per_byte": intensity,
        "achieved_gflops": k["achieved_gflops"],
        "peak_at_this_intensity": bound,
        "utilization_pct": 100 * k["achieved_gflops"] / bound,
        "bound_by": "compute" if peak_compute < peak_mem * intensity else "memory"
    }
```

### Step 5: Emit `CUDA_PROFILE_REPORT.json`

```json
{
  "audit_skill": "cuda-profile",
  "verdict": "PASS|WARN|FAIL|NOT_APPLICABLE",
  "reason_code": "profile_ok | low_occupancy | memory_bound_suboptimal | tool_unavailable",
  "summary": "4 kernels profiled. Best occupancy 87%, worst 42% (saxpy). Bench latency 1.2ms.",
  "audited_input_hashes": {"build-cuda/bench": "sha256:<hash>"},
  "trace_path": ".aris/traces/cuda-profile/<run-id>/",
  "thread_id": "cuda-profile-<timestamp>",
  "reviewer_model": "nsight-compute+nsight-systems",
  "reviewer_reasoning": "n/a",
  "generated_at": "2026-04-23T00:00:00Z",
  "details": {
    "gpu_name": "NVIDIA RTX 3090",
    "compute_cap": "8.6",
    "cuda_runtime": "13.0",
    "top_kernels": [
      {
        "name": "saxpy_kernel",
        "time_us": 320,
        "grid_dim": "[1024,1,1]",
        "block_dim": "[256,1,1]",
        "registers_per_thread": 12,
        "shared_mem_per_block_bytes": 0,
        "achieved_occupancy_pct": 87.3,
        "warp_exec_efficiency_pct": 98.2,
        "sm_utilization_pct": 82.1,
        "dram_throughput_gbs": 412.5,
        "l2_hit_rate_pct": 14.2,
        "roofline_bound_by": "memory"
      }
    ],
    "kernel_launch_overhead_us_total": 142,
    "host_device_copy_overlap_pct": 78
  }
}
```

Verdict:
- `PASS` — all profiled kernels ≥ target occupancy (default 50%)
- `WARN` — some kernels 25-50% occupancy (document in paper)
- `FAIL` — tool unavailable OR profile aborted
- `NOT_APPLICABLE` — runtime driver missing (skip gracefully, don't block draft)

## Integration

- **Upstream**: `/cuda-build`, `/cuda-sanitize` (must PASS — profiling buggy kernels is meaningless)
- **Downstream**: `/ablation-planner cuda` uses hotspot list for block-size / memory-layout sweeps; `/result-to-claim` cites specific kernel metrics
- **Audit gate**: `tools/verify_cuda_project.sh`

## Error Modes

| Failure | Fix |
|---|---|
| `ncu` requires CAP_SYS_ADMIN | Run container with `--privileged` or enable the NVIDIA perf counters interface (`sudo echo 0 > /proc/sys/kernel/perf_event_paranoid`) |
| Stub libcuda (driver mismatch) | Cannot profile — mark `NOT_APPLICABLE`; document container upgrade needed |
| Huge report file (> 1GB) | Limit scope with `--kernels regex:...` or `--launch-count N` |

## See Also

- `skills/cuda-build/SKILL.md`
- `skills/cuda-sanitize/SKILL.md`
- `skills/cuda-correctness-audit/SKILL.md`
- `shared-references/build-system-contract.md`
