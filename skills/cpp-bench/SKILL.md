---
name: cpp-bench
description: Run C++ benchmarks (Google Benchmark / Catch2 / custom) with median-of-N, 95% CI, outlier detection, and baseline comparison. Emits BENCHMARK_RESULT.json consumed by result-to-claim. Use when language=cpp and a performance claim needs empirical support.
argument-hint: [project-root] [--iterations N] [--baseline <path>]
allowed-tools: Bash(*), Read, Grep, Glob, Write, Edit
---

# C++ Benchmark

Run benchmarks with reproducibility discipline: median-of-N, confidence intervals, outlier flagging, and apples-to-apples baseline comparison.

## Activation Predicate

Fires when:
- `.aris/project.yaml` has `bench.harness ∈ {google-benchmark, catch2, custom}` AND `language: cpp`
- Invocation is explicit: `/cpp-bench [...]`
- Upstream skill needs empirical timing (e.g. `/result-to-claim` for a C++ project)

## Workflow

### Step 1: Pre-flight

```
📋 Pre-flight:
   [ ] 1. BUILD_ARTIFACT.json present and PASS (optimized, non-sanitizer build)
   [ ] 2. Bench binary exists (or build target declared in contract)
   [ ] 3. Iteration count resolved (default 10)
   [ ] 4. CPU frequency governor set to performance (warn if not)
   [ ] 5. Other high-CPU processes inactive (warn if >1 core at >50%)
```

### Step 2: Pin execution environment

```bash
# Pin CPU governor (requires privileges; warn if unavailable)
if command -v cpupower >/dev/null 2>&1; then
  sudo cpupower frequency-set -g performance 2>/dev/null || echo "WARN: cannot set performance governor"
fi
# Disable Turbo Boost for stability (optional; warn)
# echo 1 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || true
```

### Step 3: Run benchmark N iterations

```bash
BENCH_CMD=$(python3 tools/project_contract.py get-bench-cmd)
ITERATIONS="${ITERATIONS:-10}"

mkdir -p .aris/traces/cpp-bench/$(date +%s)/raw
for i in $(seq 1 $ITERATIONS); do
  eval "$BENCH_CMD" > ".aris/traces/cpp-bench/$(date +%s)/raw/run-$i.json" 2>&1
done
```

### Step 4: Aggregate (median, mean, 95% CI, outliers)

```python
import json, statistics, glob, math

runs = [json.load(open(p)) for p in glob.glob(".aris/traces/cpp-bench/*/raw/run-*.json")]
# Google Benchmark JSON: runs[*]["benchmarks"][*]["real_time"]
per_bench = {}
for run in runs:
    for b in run.get("benchmarks", []):
        per_bench.setdefault(b["name"], []).append(b["real_time"])

def ci95(data):
    n = len(data)
    m = statistics.mean(data)
    s = statistics.stdev(data) if n > 1 else 0
    margin = 1.96 * s / math.sqrt(n) if n > 1 else 0
    return m, margin

report = {name: {
    "n": len(times),
    "median_ns": statistics.median(times),
    "mean_ns": statistics.mean(times),
    "stdev_ns": statistics.stdev(times) if len(times) > 1 else 0,
    "ci95_margin_ns": ci95(times)[1],
    "cv_pct": 100 * statistics.stdev(times) / statistics.mean(times) if len(times) > 1 else 0,
    "outlier_count": sum(1 for t in times if abs(t - statistics.median(times)) > 3 * (statistics.stdev(times) if len(times) > 1 else 0)),
} for name, times in per_bench.items()}
```

### Step 5: Baseline comparison (if --baseline provided)

```python
baseline = json.load(open(BASELINE_PATH))
for name, cur in report.items():
    if name in baseline:
        speedup = baseline[name]["median_ns"] / cur["median_ns"]
        cur["speedup_vs_baseline"] = speedup
        cur["significant"] = speedup > 1 + 2 * cur["cv_pct"] / 100   # rough sig test
```

### Step 6: Emit `BENCHMARK_RESULT.json`

```json
{
  "audit_skill": "cpp-bench",
  "verdict": "PASS|WARN|FAIL",
  "reason_code": "stable | high_variance | outliers_excessive | bench_binary_missing",
  "summary": "12 benchmarks, median-of-10, max CV 3.2%, 0 outliers.",
  "audited_input_hashes": {"build/bench": "sha256:<hash>"},
  "trace_path": ".aris/traces/cpp-bench/<run-id>/",
  "thread_id": "cpp-bench-<timestamp>",
  "reviewer_model": "n/a",
  "reviewer_reasoning": "n/a",
  "generated_at": "2026-04-23T00:00:00Z",
  "details": {
    "harness": "google-benchmark",
    "iterations": 10,
    "benchmarks": { /* per_bench report from Step 4 */ },
    "baseline_path": ".aris/baseline/bench-main.json",
    "environment": {
      "cpu_governor": "performance",
      "turbo_boost": "on",
      "load_avg": "0.4"
    }
  }
}
```

Verdict:
- `PASS` — max CV ≤ 5%, outlier_count ≤ N/10 per benchmark
- `WARN` — CV 5–10% or moderate outliers (results usable but report the noise)
- `FAIL` — CV > 10% or bench binary absent

## Integration

- **Upstream**: `/cpp-build` produces the bench binary; `/cpp-sanitize` must be PASS on a non-opt build (separate concern)
- **Downstream**: `/result-to-claim` consumes `BENCHMARK_RESULT.json` as evidence for quantitative claims in the paper
- **Audit gate**: `verify_paper_audits.sh` requires BENCHMARK_RESULT.json at `assurance: submission` when `language: cpp`

## Error Modes

| Failure | Fix |
|---|---|
| CV > 10% | Reduce concurrent load, pin to single core with `taskset`, increase iterations |
| Outliers > 10% | Check for thermal throttling (`lm-sensors`) and I/O contention |
| Baseline mismatch (different binary name) | Update `--baseline` or rebuild baseline with matching target |

## See Also

- `shared-references/build-system-contract.md`
- `skills/cpp-profile/SKILL.md` — for localization of regressions
- `skills/result-to-claim/SKILL.md` — consumes the JSON
