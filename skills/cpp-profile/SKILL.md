---
name: cpp-profile
description: Profile C++ binaries with perf / valgrind / cachegrind to identify hot paths, cache-miss rate, branch-mispredict rate; emit PROFILE_REPORT.json. Use when a benchmark regression or perf claim needs localization.
argument-hint: [binary-path] [--tool perf|valgrind|cachegrind]
allowed-tools: Bash(*), Read, Grep, Glob, Write, Edit
---

# C++ Profile

Locate hot paths and micro-architectural bottlenecks for C++ binaries. Emit a structured `PROFILE_REPORT.json` that downstream skills (ablation-planner, result-to-claim, rebuttal) can read.

## Activation Predicate

Fires when:
- `.aris/project.yaml` has `profile.cpu_tool ∈ {perf, valgrind, cachegrind}` AND `language: cpp`
- Invocation is explicit: `/cpp-profile [binary] [--tool ...]`
- Triggered as follow-up when `/cpp-bench` reports a regression or `FAIL`

## Workflow

### Step 1: Select tool

```bash
TOOL=$(python3 tools/project_contract.py show | python3 -c "import json,sys; print((json.load(sys.stdin).get('profile') or {}).get('cpu_tool','perf'))")
TOOL="${TOOL_FLAG:-$TOOL}"
```

### Step 2: Run under the chosen tool

**perf** (default — lowest overhead, Linux):
```bash
perf record -F 999 -g --call-graph dwarf -o perf.data -- ./build/bench
perf report -i perf.data --no-children > perf-report.txt
perf stat -e cache-misses,cache-references,branch-misses,branches -- ./build/bench 2> perf-stat.txt
```

**valgrind** (heap / leak tracking):
```bash
valgrind --tool=memcheck --leak-check=full --xml=yes --xml-file=valgrind.xml ./build/bench
```

**cachegrind** (cache + branch simulation — slow but accurate):
```bash
valgrind --tool=cachegrind --cachegrind-out-file=cachegrind.out ./build/bench
cg_annotate cachegrind.out > cachegrind-report.txt
```

### Step 3: Extract structured findings

```python
import re, json, subprocess

# perf: top 10 symbols by self time
top = []
with open("perf-report.txt") as f:
    for line in f:
        m = re.match(r"\s*(\d+\.\d+)%\s+.*\s+(\S+)\s*$", line)
        if m and len(top) < 10:
            top.append({"symbol": m.group(2), "self_pct": float(m.group(1))})

# perf stat: cache miss rate, branch mispredict rate
def parse_stat(path):
    out = {}
    for line in open(path):
        m = re.match(r"\s+([\d,]+)\s+(\S+)", line)
        if m:
            out[m.group(2)] = int(m.group(1).replace(",", ""))
    return out
stat = parse_stat("perf-stat.txt")
cache_miss_rate = stat.get("cache-misses", 0) / max(stat.get("cache-references", 1), 1)
branch_miss_rate = stat.get("branch-misses", 0) / max(stat.get("branches", 1), 1)
```

### Step 4: Emit `PROFILE_REPORT.json`

```json
{
  "audit_skill": "cpp-profile",
  "verdict": "PASS|WARN|FAIL|NOT_APPLICABLE",
  "reason_code": "profile_ok | hot_path_identified | profile_failed | tool_unavailable",
  "summary": "Top hot path: fn_foo (42.3%). Cache miss rate 12%. Branch mispredict 2.1%.",
  "audited_input_hashes": {"build/bench": "sha256:<hash>"},
  "trace_path": ".aris/traces/cpp-profile/<run-id>/",
  "thread_id": "cpp-profile-<timestamp>",
  "reviewer_model": "n/a",
  "reviewer_reasoning": "n/a",
  "generated_at": "2026-04-23T00:00:00Z",
  "details": {
    "tool": "perf",
    "top_hotspots": [
      {"symbol": "fn_foo", "self_pct": 42.3, "file": "src/foo.cpp", "line": 120}
    ],
    "cache_miss_rate": 0.12,
    "branch_mispredict_rate": 0.021,
    "instructions_retired": 12345678901,
    "cycles": 10000000000
  }
}
```

Verdict:
- `PASS` — profile produced; no aberrations flagged
- `WARN` — cache miss rate > 20% OR branch mispredict > 5%
- `FAIL` — tool unavailable OR profile aborted
- `NOT_APPLICABLE` — `profile.cpu_tool` unset in contract AND no tool requested

## Integration

- **Upstream**: `/cpp-bench` triggers profiling on regression
- **Downstream**: `/ablation-planner cpp-algo` uses hotspot list to pick ablation targets; `/result-to-claim` and `/rebuttal` cite specific hotspots when defending efficiency claims

## Error Modes

| Failure | Root cause | Fix |
|---|---|---|
| "perf_event_open() failed" | `kernel.perf_event_paranoid > 2` | `sudo sysctl kernel.perf_event_paranoid=-1` or run via container with CAP_SYS_ADMIN |
| valgrind 10x slowdown | Expected | Use `perf` for production-speed profiling; valgrind for correctness only |
| Flat profile (all same %) | Binary stripped of symbols | Rebuild with `-g`, keep symbols |

## See Also

- `skills/cpp-bench/SKILL.md` — upstream benchmark
- `skills/cpp-build/SKILL.md` — must build with `-g` to retain symbols
- `shared-references/assurance-contract.md`
