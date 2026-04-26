---
name: complexity-claim-audit
description: Zero-context audit of every asymptotic claim (\mathcal{O}, \Theta, \Omega, "amortized O(1)", "O(n log n)") in the paper, cross-referenced against formal proofs in the appendix. Uses a fresh reviewer to catch parameter hiding, hidden constants, and unproven bounds. Emits COMPLEXITY_AUDIT.json. Use at assurance=submission for any paper with algorithmic bounds.
argument-hint: [paper-directory]
allowed-tools: Bash(*), Bash(codex*), Read, Write, Grep, Glob, Skill(codex:rescue)
---

# Complexity Claim Audit

Verify that every asymptotic complexity claim in the paper (running time, space, communication, I/O) is backed by a formal proof, with parameters tracked and hidden factors disclosed — for: **$ARGUMENTS**

## Why This Exists

Paper-claim-audit catches numeric mismatches in experimental tables. It does NOT audit asymptotic claims, because the relevant evidence is a proof in the appendix, not a raw JSON number. Authors (including fresh executors) routinely:

- State "O(n)" when the actual bound is "O(n log k)" in k-th iterate
- Claim "amortized O(1)" without either an accounting or potential argument
- Hide a 100× constant factor ("O(n log n)" with a constant of 2^30)
- Assume unstated properties of inputs (sorted, unique, well-formed)
- Drop log factors in the abstract that reappear in the proof

Theory venues (SODA, STOC, ICALP, SPAA) and the algorithmic systems venues (PLDI, SC) REJECT papers with unverified bounds. This skill is the external gate.

## Activation Predicate

**This skill is opt-in.** It applies only when the paper actually makes asymptotic complexity claims. A SLAM / perception / NLP / LLM / graphics / robotics paper that simply reports empirical latency or accuracy **does NOT need this skill** — `paper-claim-audit` Phase C.4 skips the cross-reference when no asymptotic symbols are present.

Fires when all of:
1. Paper contains at least one `\mathcal{O}`, `\Theta`, `\Omega`, `O(`, `Θ(`, `Ω(` regex match in any `.tex` file (empirical speedup statements like "3× faster" or "p99 < 10 ms" do NOT count).
2. `assurance ∈ {draft, submission}` AND
3. Invocation via `/paper-writing` Phase 6 (auto-gated on Condition 1) or explicit `/complexity-claim-audit <dir>`.

Papers at `venue_family ∈ {theory, pl, systems, hpc, db}` most commonly trigger this. Robotics / CV / NLP / graphics papers typically do not — and ARIS does not force them to.

## How This Differs From Other Audits

| Skill | Question |
|---|---|
| `/proof-checker` | Are the proofs mathematically correct? (rigor) |
| `/paper-claim-audit` | Do numeric tables match raw JSON files? (empirical) |
| **`/complexity-claim-audit`** | **Does every asymptotic statement have a proof, with parameters and constants honestly disclosed?** |

## Workflow

### Step 1: Collect claims (executor)

Extract every complexity claim in the paper body:

```bash
grep -nE "\\\\mathcal\{O\}|\\\\Theta|\\\\Omega|O\s*\(|Θ\s*\(|Ω\s*\(|amortized O" paper/main.tex paper/sections/*.tex > .aris/complexity-claims.txt
```

Normalize each hit into a structured record: `{file, line, raw, normalized (e.g. "O(n log n)"), stated_params}`.

### Step 2: Fresh reviewer audit (zero-context)

Invoke a fresh reviewer thread via `/codex:rescue` (no history, no executor summaries). Provide ONLY:

- `paper/main.tex`
- `paper/sections/*.tex`
- `paper/appendix.tex` (proofs)
- `.aris/complexity-claims.txt`

```
/codex:rescue --effort xhigh "
CRITICAL: Fresh-context complexity audit.

For each claim in .aris/complexity-claims.txt, answer ALL of:

1. PROOF LINKAGE
   - Is there a corresponding Theorem/Lemma in main or appendix that formally states this bound?
   - If yes: cite its label. If no: MARK 'unproven'.

2. PARAMETER TRACKING
   - Which input parameters does the bound depend on? (n, k, d, log d, etc.)
   - Does the proof handle ALL of those parameters, or are some implicit assumptions dropped?
   - Example violation: claim 'O(n)' but proof assumes sorted input that costs O(n log n) to prepare.

3. HIDDEN CONSTANT
   - Does the proof give an explicit constant (even an upper bound)?
   - If the constant is > 1024 or depends on another parameter, flag 'hidden_constant'.

4. UNIFORMITY
   - Does the bound hold for ALL valid inputs, or only 'typical' / 'random' inputs?
   - Average-case, worst-case, amortized, or expected: which one?
   - Flag 'non_uniform' if the claim hides the input distribution.

5. LOWER BOUND TIGHTNESS (if the paper claims optimality)
   - Does a matching lower bound exist in the paper or cited?
   - If claimed 'optimal' without a lower bound: flag 'tightness_unverified'.

Output JSON with per-claim verdicts: PASS / WARN / FAIL / UNPROVEN / HIDDEN_CONSTANT / NON_UNIFORM / TIGHTNESS_UNVERIFIED.
"
```

### Step 3: Synthesize `COMPLEXITY_AUDIT.json`

Per-claim records plus overall verdict:

```json
{
  "audit_skill": "complexity-claim-audit",
  "verdict": "PASS|WARN|FAIL|NOT_APPLICABLE",
  "reason_code": "all_proven | unproven_claims | hidden_constants | non_uniform_bounds | tightness_unverified | no_complexity_claims",
  "summary": "12 complexity claims, 10 PASS, 2 WARN (hidden constants), 0 FAIL.",
  "audited_input_hashes": {
    "main.tex": "sha256:<hash>",
    "sections/": "sha256:<tree-hash>",
    "appendix.tex": "sha256:<hash>"
  },
  "trace_path": ".aris/traces/complexity-claim-audit/<run-id>/",
  "thread_id": "complexity-claim-audit-<timestamp>",
  "reviewer_model": "gpt-5.4",
  "reviewer_reasoning": "xhigh",
  "generated_at": "2026-04-23T00:00:00Z",
  "details": {
    "claim_count": 12,
    "verdict_counts": {"PASS": 10, "WARN": 2, "FAIL": 0},
    "claims": [
      {
        "claim_id": "c1",
        "file": "sections/algorithm.tex",
        "line": 42,
        "raw": "\\mathcal{O}(n \\log n)",
        "normalized": "O(n log n)",
        "verdict": "PASS",
        "proof_ref": "theorem:main",
        "parameters": ["n"],
        "hidden_constant": false,
        "uniformity": "worst-case"
      },
      {
        "claim_id": "c7",
        "raw": "amortized O(1)",
        "verdict": "WARN",
        "reason": "hidden_constant",
        "note": "Constant factor 2^24 disclosed in proof but not in abstract."
      }
    ]
  }
}
```

Verdict mapping:
- `PASS` — all claims linked to proofs, parameters tracked, constants bounded
- `WARN` — some claims have hidden constants or non-uniform bounds but are mathematically correct; paper should disclose in abstract
- `FAIL` — at least one claim is unproven or has an invalid proof
- `NOT_APPLICABLE` — no asymptotic claims in the paper (regex match empty)

### Step 4: Blocking behavior

At `assurance: submission` with `venue_family ∈ {theory, pl, systems, hpc}`, `verify_paper_audits.sh` treats `verdict ∈ {FAIL, WARN}` as exit 1 blocker (WARN is acceptable at `draft` assurance).

## Multi-Turn Dispute Protocol

When the reviewer flags claims that the executor disputes:

1. Executor writes a structured rebuttal JSON under `.aris/disputes/complexity-<claim_id>-round-1.json`:
   ```json
   {"claim_id": "c7", "reviewer_verdict": "WARN", "executor_argument": "The 2^24 constant is not hidden; it's stated in Lemma 4.2.", "citation": "lemma:4.2:line-12"}
   ```
2. Resubmit via `/codex:rescue` with the rebuttal + original paper — max 3 rounds.
3. After round 3, record `final_verdict` in audit JSON — no more disputes.

See `shared-references/codex-context-integrity.md` for the general dispute protocol.

## Integration

- **Upstream**: `/paper-writing` Phase 4.7 (theorem detection) triggers this skill; `/proof-checker` runs first to validate proof correctness
- **Downstream**: `/paper-claim-audit` Phase C.4 re-reads `COMPLEXITY_AUDIT.json` to correlate asymptotic claims with empirical tables
- **Audit gate**: `tools/verify_paper_audits.sh` reads the JSON and gates submission

## Backfill

If an older paper lacks this audit:
```bash
/complexity-claim-audit paper/
# Force rerun ignoring stale hashes:
/complexity-claim-audit paper/ --force-refresh
```

## Known Failure Patterns (seeds in research-wiki/failures/)

- `hidden-asymptotic-constant` — O(n) with 100× constant beaten in practice by O(n log n)
- `parameter-hiding` — claim O(n) when proof depends on another parameter k secretly

## See Also

- `shared-references/assurance-contract.md` — 10-field JSON template
- `shared-references/codex-context-integrity.md` — dispute protocol
- `skills/proof-checker/SKILL.md` — validates individual proofs
- `skills/paper-claim-audit/SKILL.md` — empirical side
