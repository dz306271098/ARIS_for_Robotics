---
name: cpp-sanitize
description: Build and run C++ binaries under ASan / UBSan / TSan / MSan, parse sanitizer reports, and emit SANITIZER_AUDIT.json. Blocks assurance=submission on any non-clean run. Use when language=cpp and submission-quality evidence is required.
argument-hint: [project-root] [--sanitizer address|undefined|thread|memory|all]
allowed-tools: Bash(*), Read, Grep, Glob, Write, Edit
---

# C++ Sanitizer Audit

Runtime correctness gate: build the project with one or more `-fsanitize=…` modes, execute tests/benchmarks, parse sanitizer reports into structured findings, and emit `SANITIZER_AUDIT.json`.

## Activation Predicate

Fires when:
- `.aris/project.yaml` has `language: cpp` AND `sanitizers.cpu` is non-empty
- `assurance: submission` is set (sanitizer clean is mandatory at submission)
- Invocation is explicit: `/cpp-sanitize [--sanitizer …]`

## Workflow

### Step 1: Pre-flight checklist

```
📋 Pre-flight:
   [ ] 1. BUILD_ARTIFACT.json present (or rebuild with sanitizer flags)
   [ ] 2. Sanitizer list resolved from contract or --sanitizer flag
   [ ] 3. Test / bench binary identified in build/
   [ ] 4. LSAN_OPTIONS / ASAN_OPTIONS / TSAN_OPTIONS / UBSAN_OPTIONS set to abort_on_error=1
```

### Step 2: Resolve sanitizer list

```bash
SANS=$(python3 - <<'PY'
import json, subprocess
cfg = json.loads(subprocess.check_output(["python3","tools/project_contract.py","show"]).decode())
print(" ".join((cfg.get("sanitizers") or {}).get("cpu", [])))
PY
)
SANS="${SANS:-address undefined}"  # default
```

Conflict: ASan + TSan + MSan are mutually exclusive (different runtime). Iterate one at a time.

### Step 3: Build + run per sanitizer

```bash
for SAN in $SANS; do
  CFLAGS="-g -O1 -fsanitize=$SAN -fno-omit-frame-pointer"
  # Rebuild with sanitizer flags — separate build dir to preserve cache
  cmake -S . -B build-san-$SAN -DCMAKE_BUILD_TYPE=Debug -DCMAKE_CXX_FLAGS="$CFLAGS" -DCMAKE_EXE_LINKER_FLAGS="-fsanitize=$SAN"
  cmake --build build-san-$SAN -j
  # Run tests under sanitizer
  export ${SAN^^}_OPTIONS="abort_on_error=0:exitcode=42:print_stacktrace=1"
  ./build-san-$SAN/tests 2> sanitizer-$SAN.log || true
  ./build-san-$SAN/bench --iterations=1 2>> sanitizer-$SAN.log || true
done
```

### Step 4: Parse findings

Each sanitizer emits a stable prefix in stderr:
- ASan: `==PID==ERROR: AddressSanitizer: <type> …`
- UBSan: `<file>:<line>: runtime error: <description>`
- TSan: `WARNING: ThreadSanitizer: <type> …`
- MSan: `==PID==ERROR: MemorySanitizer: <type> …`

Parse into a findings list with `{sanitizer, type, location, trace_snippet}`.

### Step 5: Emit `SANITIZER_AUDIT.json`

```json
{
  "audit_skill": "cpp-sanitize",
  "verdict": "PASS|FAIL|NOT_APPLICABLE",
  "reason_code": "clean | findings_present | no_sanitizers_configured",
  "summary": "3 sanitizers run (address, undefined, thread). 0 findings.",
  "audited_input_hashes": {
    "main.cpp": "sha256:<hash>",
    "src/": "sha256:<tree-hash>"
  },
  "trace_path": ".aris/traces/cpp-sanitize/<run-id>/",
  "thread_id": "cpp-sanitize-<timestamp>",
  "reviewer_model": "clang-sanitizer-runtime",
  "reviewer_reasoning": "n/a",
  "generated_at": "2026-04-23T00:00:00Z",
  "details": {
    "sanitizers_run": ["address", "undefined", "thread"],
    "findings_count_by_sanitizer": {"address": 0, "undefined": 0, "thread": 0},
    "findings": [],
    "build_time_s_total": 34.2,
    "runtime_s_total": 8.7
  }
}
```

Verdict rules:
- `PASS` — all configured sanitizers report 0 findings
- `FAIL` — any finding
- `NOT_APPLICABLE` — `sanitizers.cpu` empty in contract (at `assurance: submission`, FAIL instead)

### Step 6: Blocking behavior

At `assurance: submission`, `verify_paper_audits.sh` treats `verdict != PASS` as exit 1 blocker.

## Integration

- **Upstream**: `/cpp-build` — runs first to establish baseline binary
- **Downstream**: `/cpp-bench` — may choose to rerun bench with ASan off for accurate timing
- **Audit gate**: `tools/verify_cpp_project.sh` + `tools/verify_paper_audits.sh`

## Backfill

If an older run lacks this audit at submission:
```bash
/cpp-sanitize --sanitizer all
# Or use the canonical helper:
bash tools/verify_cpp_project.sh
```

## Known Failure Patterns (seeds in research-wiki/failures/)

- `ub-exploit-compiler-optimization` — `-O3` vs `-O1 -fsanitize=undefined` disagreeing on program behavior reveals UB
- `race-condition-data-race` — TSan-detectable data race only triggers at thread count > 4
- `cache-thrash-false-sharing` — false-sharing visible in `perf c2c` but not in functional tests

## See Also

- `shared-references/build-system-contract.md`
- `shared-references/assurance-contract.md`
- `skills/cpp-build/SKILL.md`
- `tools/verify_cpp_project.sh`
