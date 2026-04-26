---
name: paper-claim-audit
description: "Zero-context verification that every number, comparison, and scope claim in the paper matches raw result files. Uses a fresh cross-model reviewer with NO prior context to prevent confirmation bias. Use when user says \"审查论文数据\", \"check paper claims\", \"verify numbers\", \"论文数字核对\", or before submission to ensure paper-to-evidence fidelity."
argument-hint: [paper-directory]
allowed-tools: Bash(*), Bash(codex*), Read, Write, Edit, Grep, Glob, Skill(codex:rescue)
---

# Paper Claim Audit: Zero-Context Evidence Verification

Verify that every claim in the paper matches raw evidence for: **$ARGUMENTS**

## Why This Exists

The executor writes experiments AND writes the paper. It "knows" what the results should be. This creates confirmation bias:
- Rounding 84.7% up to 85.3%
- Reporting best seed instead of average
- Citing metrics from a different experiment config
- Claiming "improves by 15%" when the delta is actually 12.8%

A **fresh reviewer with zero prior context** catches these because it has no expectations -- it just compares paper text vs raw files.

## How This Differs From Other Audit Skills

| Skill | Question it answers |
|-------|-------------------|
| `/experiment-audit` | Is the experiment code honest? (fake GT, normalization fraud) |
| `/result-to-claim` | Does the data scientifically support this claim? |
| **`/paper-claim-audit`** | **Does the paper report the data truthfully and precisely?** |

## Core Principle

**Zero-context, fresh reviewer.** The auditor receives ONLY:
- Paper .tex files (the claims)
- Raw result files (the evidence)

It does NOT receive:
- EXPERIMENT_LOG.md
- EXPERIMENT_TRACKER.md
- AUTO_REVIEW.md
- NARRATIVE_REPORT.md
- Any executor summary or interpretation
- Any prior audit results
- Any conversation history

This is **stricter than reviewer-independence** -- it's zero-context evidence audit.

## Workflow

### Step 1: Collect Files (Executor -- Claude)

Locate paper and result files WITHOUT reading or interpreting them.

**Paper files** (claims):
```
paper/main.tex
paper/sections/*.tex
paper/tables/*.tex (if separate)
```

**Result files** (evidence):
```
results/*.json, results/*.jsonl, results/*.csv, results/*.tsv
outputs/*.json, outputs/*.csv
wandb-summary.json (if exists)
**/metrics.json, **/eval_results.json
**/config.yaml, **/args.json (experiment configs)
```

**Exclude** (no summaries, no interpretations):
```
EXPERIMENT_LOG.md, EXPERIMENT_TRACKER.md, AUTO_REVIEW*.md
NARRATIVE_REPORT.md, PAPER_PLAN.md, findings.md
Any .md file that is an executor-written summary
```

### Step 2: Fresh Reviewer Audit (GPT-5.4 -- NEW thread, no resume)

**CRITICAL: Always use a fresh `codex exec` call. NEVER use `codex exec resume --last`. Every run must be a fresh context with zero prior information.**

```bash
codex exec --sandbox read-only -m gpt-5.4 "
You are a paper-to-evidence auditor. You have ZERO prior context about
this research. You will receive only paper source files and raw result
files. Your job is to verify that every number in the paper exactly
matches the raw evidence.

Paper files to read:
[list .tex file paths]

Result files to read:
[list .json/.csv/.yaml file paths]

## Audit Protocol

### A. Extract Every Quantitative Claim
For each number, percentage, comparison, or scope statement in the paper:
- Location (section, table, caption, or inline text)
- Exact claim text
- The number or comparison being made

### B. Trace Each Claim to Evidence
For each extracted claim, find the supporting raw data:
- Which result file contains this number?
- What is the EXACT value in that file?
- Match status: exact_match / rounding_ok / mismatch

### C. Check These Specific Failure Modes

1. **Number inflation**: Paper says 85.3%, raw file says 84.7%
   Rule: only standard rounding to displayed precision is allowed

2. **Best-seed cherry-pick**: Paper says 'achieves 90.2%' but
   that is the best of 5 seeds; mean is 87.1%
   Rule: check if paper specifies 'average' / 'best' / 'median'

3. **Config mismatch**: Paper compares Method A vs Baseline B,
   but they used different hyperparameters / datasets / splits
   Rule: verify config files show same settings for compared methods

4. **Aggregation mismatch**: Paper says 'average over 5 seeds'
   but result files show only 3 runs
   Rule: count actual runs vs claimed count

5. **Delta error**: Paper says 'improves by 15%' but
   actual delta is (85.3 - 73.1) / 73.1 = 16.7%
   Rule: verify arithmetic of all relative improvements

6. **Caption-table mismatch**: Figure caption describes
   something different from what the figure/table actually shows
   Rule: cross-check every caption against its content

7. **Scope overclaim**: Paper says 'consistently outperforms'
   but only tested on 2 datasets
   Rule: check if language matches actual evaluation scope

## Output Format (per claim)
For each claim, report:
- claim_id: sequential number
- location: section/table/figure
- paper_text: exact quote from paper
- paper_value: the number claimed
- evidence_file: which raw file
- evidence_value: the actual number
- status: exact_match | rounding_ok | ambiguous_mapping |
          missing_evidence | config_mismatch | aggregation_mismatch |
          number_mismatch | scope_overclaim | unsupported_claim
- details: explanation if not exact_match

Overall verdict: PASS | WARN | FAIL
"
```

### Step 3: Write Report (Executor -- Claude)

Parse the reviewer's response and write `PAPER_CLAIM_AUDIT.md`:

```markdown
# Paper Claim Audit Report

**Date**: [today]
**Auditor**: GPT-5.4 xhigh (fresh zero-context thread via Codex CLI)
**Paper**: [paper title from tex]

## Overall Verdict: [PASS | WARN | FAIL]

## Claims Verified: [N total]
- exact_match: [count]
- rounding_ok: [count]
- ambiguous_mapping: [count]
- missing_evidence: [count]
- mismatch: [count]

## Issues Found

### [FAIL/WARN] Claim #N: [description]
- **Location**: Section X / Table Y / Figure Z
- **Paper says**: "..."
- **Evidence shows**: ...
- **Status**: [status]
- **Fix**: [specific correction needed]

## All Claims (detailed)

| # | Location | Paper Value | Evidence Value | Status |
|---|----------|-------------|---------------|--------|
| 1 | Table 2 | 85.3% | 85.28% | rounding_ok |
| 2 | Abstract | "15% improvement" | 12.8% | number_mismatch |
| ... |
```

Also write `PAPER_CLAIM_AUDIT.json` for machine consumption.

### Step 4: Print Summary

```
Paper Claim Audit Complete

  Claims verified: 24
  exact_match:     18
  rounding_ok:      3
  ambiguous:         1
  mismatch:          2

  Overall: WARN

  See PAPER_CLAIM_AUDIT.md for details.
```

## When to Run

1. **After `/paper-write`** -- first check before improvement loop
2. **After `/auto-paper-improvement-loop`** -- recheck if improvement loop changed numbers
3. **Before submission** -- final verification

## Integration with Other Skills

### Read by `/auto-paper-improvement-loop` (if exists)

```
if PAPER_CLAIM_AUDIT.json exists:
    read mismatched claims
    fix them as priority items in the improvement round
```

### Advisory, Never Blocking

Same pattern as `/experiment-audit`:
- `PASS` -> continue normally
- `WARN` -> print warning, continue, flag draft as "check numbers before submission"
- `FAIL` -> print alert, continue, but do NOT mark as submission-ready

## Key Rules

- **Fresh thread EVERY run.** Never use `codex exec resume --last`. Never carry context.
- **Zero executor interpretation.** Only file paths. No summaries.
- **Only raw results.** No EXPERIMENT_LOG, no AUTO_REVIEW, no human summaries.
- **Rounding rule.** Only standard rounding to displayed precision. 84.7% -> 84.7% or 85% is OK. 84.7% -> 85.3% is NOT OK.
- **Cross-model.** Reviewer must be a different model family from executor.

## Review Tracing

After each `codex exec` reviewer call, save the trace following `shared-references/review-tracing.md`. Use `tools/save_trace.sh` or write files directly to `.aris/traces/<skill>/<date>_run<NN>/`. Respect the `--- trace:` parameter (default: `full`).

## Submission Artifact Emission

This skill **always** writes `paper/PAPER_CLAIM_AUDIT.json`, regardless of caller or detector outcome. A paper with no numeric claims emits verdict `NOT_APPLICABLE`; silent skip is forbidden. `paper-writing` Phase 6 and `tools/verify_paper_audits.sh` both rely on this artifact existing at a predictable path.

The artifact conforms to the schema in `shared-references/assurance-contract.md`:

```json
{
  "audit_skill":      "paper-claim-audit",
  "verdict":          "PASS | WARN | FAIL | NOT_APPLICABLE | BLOCKED | ERROR",
  "reason_code":      "all_numbers_match | number_mismatch | no_raw_evidence | ...",
  "summary":          "One-line human-readable verdict summary.",
  "audited_input_hashes": {
    "main.tex":                   "sha256:...",
    "sections/5.evidence.tex":    "sha256:...",
    "/absolute/path/results/run.json": "sha256:..."
  },
  "trace_path":       ".aris/traces/paper-claim-audit/<date>_run<NN>/",
  "thread_id":        "<codex thread id>",
  "reviewer_model":   "gpt-5.4",
  "reviewer_reasoning": "xhigh",
  "generated_at":     "<UTC ISO-8601>",
  "details": {
    "total_claims":         <int>,
    "number_mismatch":      <int>,
    "aggregation_mismatch": <int>,
    "config_mismatch":      <int>,
    "per_claim":            [ { "section": "5.2", "claim": "accuracy = 89.2%",
                                "verdict": "MATCH | MISMATCH | BLOCKED",
                                "note": "..." }, ... ]
  }
}
```

### `audited_input_hashes` scope

Hash the declared input set: `main.tex`, every `sections/*.tex` that contains numeric claims, AND every `results/*.json` / `results/*.csv` file consulted for verification. Use paths relative to the paper directory for in-paper files; absolute paths for external result files (e.g. `/home/me/project/results/run.json`). Do NOT hash `/tmp/*` or transient staging files — if you need to stage extracted numbers, materialize them under `paper/.aris/paper-claim-audit/` so the verifier can rehash.

### Verdict decision table

| Input state | Verdict | `reason_code` example |
|-------------|---------|----------------------|
| No numeric claims in paper | `NOT_APPLICABLE` | `no_numeric_claims` |
| Claims present but no `results/` or referenced data | `BLOCKED` | `no_raw_evidence` |
| All numbers match raw data | `PASS` | `all_numbers_match` |
| Minor aggregation / rounding differences only | `WARN` | `rounding_drift` |
| Any `MISMATCH` with material numerical difference | `FAIL` | `number_mismatch` |
| Reviewer invocation failed / malformed output | `ERROR` | `reviewer_error` |

### Thread independence

Every invocation uses a fresh `codex exec` session. Never `codex exec resume --last`. Do not accept prior audit outputs as input — reviewer independence per `shared-references/reviewer-independence.md` and `shared-references/assurance-contract.md` ("always emit, never block").

This skill never blocks by itself; `paper-writing` Phase 6 plus `tools/verify_paper_audits.sh` decide whether the verdict blocks finalization based on the `assurance` level. The `PAPER_CLAIM_AUDIT.md` human-readable report remains, side-by-side with the JSON artifact.

### Phase C.4 — Asymptotic claim audit (v2.2+, opt-in)

**Only active when the paper actually makes asymptotic claims.** Pattern-match `\mathcal{O}` / `\Theta` / `\Omega` / "amortized O(1)" / "O(n log n)" in the paper body; if **no matches**, set verdict `NOT_APPLICABLE` with reason_code `no_asymptotic_claims` and skip this phase. Most SLAM / perception / NLP / LLM / graphics / robotics papers report empirical numbers only and land here — that is expected, not a gap.

When matches DO exist, delegate the audit itself to `/complexity-claim-audit` (emits `COMPLEXITY_AUDIT.json`). In paper-claim-audit we only cross-reference empirical evidence: if the paper cites "O(n log n) running time" in a caption adjacent to an empirical scaling table, check the table's scaling fits the claim. Verdict reason codes: `complexity_empirical_mismatch`, `asymptotic_audit_missing_but_required` (when `\mathcal{O}` present but `COMPLEXITY_AUDIT.json` absent at submission).

### Phase C.5 — Real-time claim audit (v2.2+, robotics)

When `frameworks` includes `ros2` AND paper body has latency (ms, μs) or frequency (Hz) claims, verify each against `ROS2_REALTIME_AUDIT.json`:

- "100 Hz control" → `observed_rate_hz ≥ 100` in the audit
- "p99 latency 10 ms" → `p99_ms ≤ 10` in the audit
- Missing audit at submission → `realtime_unverified`
- Mismatch (claim 100 Hz, audit shows 92 Hz) → `realtime_deadline_missed`

### Phase C.6 — GPU-throughput / occupancy claim audit (v2.2+, gpu)

When `frameworks` includes `cuda` AND paper body has TFLOPS / DRAM-throughput / occupancy / warp-efficiency claims, verify each against `CUDA_PROFILE_REPORT.json`:

- "Achieves 412 GB/s DRAM throughput" → `dram_throughput_gbs ≥ 412` for the named kernel
- "87% SM occupancy" → `achieved_occupancy_pct` matches within 2%
- Missing audit at submission → `gpu_metrics_unverified`
- Mismatch → `occupancy_claim_overstated` or `throughput_claim_overstated`

Numerical claims of accuracy drop for TRT engines delegate similarly to `TRT_ENGINE_AUDIT.json`.

## See Also

- `/citation-audit` — sibling skill for bibliographic integrity
- `/proof-checker` — sibling skill for theorem verification
- `/experiment-audit` — sibling skill for evaluation code integrity
- `/complexity-claim-audit` — asymptotic bound audit (v2.2+)
- `/ros2-realtime-audit` — real-time claim source (v2.2+)
- `/cuda-profile` — GPU metrics source (v2.2+)
- `shared-references/assurance-contract.md` — 6-verdict state machine + artifact schema
- `shared-references/integration-contract.md` — architectural contract for cross-skill integration
