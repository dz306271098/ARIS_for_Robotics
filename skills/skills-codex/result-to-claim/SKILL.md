---
name: result-to-claim
description: "Use when experiments complete to judge what claims the results support, what they do not, and what evidence is still missing. A secondary Codex reviewer evaluates the evidence, then the executor routes to salvage, supplement, or confirmation."
argument-hint: [experiment-description-or-wandb-run]
allowed-tools: Bash(*), Read, Grep, Glob, Write, Edit, Agent
---

# Result-to-Claim Gate

Experiments produce numbers; this gate decides what those numbers actually justify. Collect the evidence, get an external judgment, then route aggressively based on the verdict.

## Context: $ARGUMENTS

## Constants

- **REVIEWER_MODEL = `gpt-5.4`** — Used via a secondary Codex reviewer agent.
- **REPEAT_PARTIAL_THRESHOLD = 2** — After two `partial` verdicts on the same claim, escalate to a deeper failure analysis instead of drifting forever.
- **AUTONOMY_PROFILE = `CODEX.md -> ## Autonomy Profile`** — Source of reviewer fallback policy in unattended-safe mode.
- **AUTONOMY_STATE = `AUTONOMY_STATE.json`** — Cross-workflow state anchor for claim-freeze progress, provisional reviewer fallback, and replay requirements.

## When to Use

- After a main experiment block completes
- Before you lock claims into a paper, review response, or summary memo
- When the result is positive but the scope of that positivity is unclear

## Unattended Safe Mode

When `CODEX.md -> ## Autonomy Profile` sets `autonomy_mode: unattended_safe`:

- update `AUTONOMY_STATE.json` before evidence collection, after the verdict, and on any blocker
- retry reviewer runtime first according to `max_reviewer_runtime_retries`
- if `review_fallback_mode: retry_then_local_critic`, a provisional local-critic pass is allowed only to keep the workflow moving; set `review_mode=local_fallback`, `review_replay_required=true`, and a concise `recovery_step`
- never treat a provisional local-critic verdict as the final paper-ready claim freeze; replay the external reviewer before final completion


## Workflow

### Step 1: Collect the Full Evidence Package

Pull evidence from the best sources available:

1. **W&B** — metrics, learning curves, seed tables, baseline comparisons
2. **`EXPERIMENT_LOG.md` / `EXPERIMENT_TRACKER.md`** — what was run and with which configs
3. **Raw result files** — JSON, CSV, TensorBoard exports, or evaluation logs
4. **`docs/research_contract.md` / `CODEX.md` / `RESEARCH_BRIEF.md`** — intended claim and success criteria
5. **Research wiki** — if `research-wiki/` exists, inspect the corresponding `idea:` / `claim:` / `exp:` pages

Assemble:

- the exact intended claim
- the tested scope: datasets, tasks, splits, ablations, seeds
- baseline provenance: reproduced vs paper-reported
- main deltas and whether they are statistically meaningful
- caveats: missing baselines, weak seeds, unstable metrics, partial runs

Write a self-contained evidence brief to `CLAIMS_FROM_RESULTS.md` before routing:

```markdown
# Claim Assessment

## Intended Claim
[the claim these experiments were meant to validate]

## Evidence Package
- Experiments: [...]
- Metrics: [...]
- Baselines: [...]
- Caveats: [...]

## Reviewer Verdict
[filled in after Step 2]
```

### Step 2: External Claim Judgment

Use a secondary reviewer so the executor does not rationalize its own results.

```text
spawn_agent:
  model: REVIEWER_MODEL
  reasoning_effort: xhigh
  message: |
    RESULT-TO-CLAIM EVALUATION

    I need an objective judgment on whether these results support the intended claim.

    Intended claim:
    [claim]

    Experiments run:
    [dataset / config / seeds / baselines]

    Results:
    [key metrics, deltas, confidence intervals or significance if available]

    Baseline provenance:
    [reproduced vs reported, tuning budget, evaluation parity]

    Known caveats:
    [missing comparisons, unstable seeds, small scope, weak significance]

    Return:
    1. claim_supported: yes | partial | no
    2. approved_claim: the strongest defensible claim
    3. unsupported_claim_parts: what the data does NOT justify
    4. missing_evidence: specific evidence gaps
    5. likely_failure_mode: implementation_error | integration_error | fundamental_flaw | insufficient_tuning | evaluation_mismatch | underspecified_claim | none
    6. suggested_claim_revision: narrower / stronger / reframe / abandon
    7. next_experiments_needed: ordered list of minimum experiments to close the gap
    8. confidence: high | medium | low

    Be strict. A positive result on one setting does not justify a general claim.
```

If delegation is unavailable, run the same rubric locally and mark the result `[pending external review]` instead of blocking. In unattended-safe mode, this local rubric is only a provisional fallback and must set `review_replay_required=true` until the external reviewer is replayed successfully.

### Step 3: Normalize the Verdict

Update `CLAIMS_FROM_RESULTS.md` with:

```markdown
- claim_supported: yes | partial | no
- approved_claim: "..."
- unsupported_claim_parts: "..."
- missing_evidence: "..."
- likely_failure_mode: "..."
- suggested_claim_revision: "..."
- next_experiments_needed: "..."
- confidence: high | medium | low
```

Always preserve the original intended claim alongside the approved claim. Do not silently weaken a claim without recording the delta.

### Step 4: Route Aggressively Based on the Verdict

#### `no` — claim not supported

Run a deeper failure analysis before abandoning the idea:

```text
spawn_agent:
  model: REVIEWER_MODEL
  reasoning_effort: xhigh
  message: |
    FAILURE ANALYSIS FOR UNSUPPORTED CLAIM

    Read the experiment evidence below and determine WHY this claim failed.

    Intended claim:
    [claim]

    Variant / implementation summary:
    [what changed]

    Evidence:
    [results, logs, caveats, baseline parity notes]

    Return:
    1. failure_class: implementation_error | integration_error | fundamental_flaw | insufficient_tuning | evaluation_mismatch | claim_too_broad
    2. root_cause: concise explanation
    3. salvageable: yes | no
    4. minimal_salvage_plan: concrete next step if salvageable
    5. what_not_to_repeat: concrete anti-patterns
```

Then route:

- `implementation_error` or `integration_error`: fix the issue, rerun the minimum validating experiment, then rerun `/result-to-claim`
- `insufficient_tuning`: run the smallest credible sweep, record the tuning hypothesis, then rerun
- `evaluation_mismatch`: fix evaluation and rerun before changing the method
- `claim_too_broad`: narrow the claim in `CLAIMS_FROM_RESULTS.md`, then decide whether the narrower claim is still worth pursuing
- `fundamental_flaw` and `salvageable = no`: record the postmortem in `findings.md`, update `CODEX.md`, and pivot to the next idea

#### `partial` — claim partially supported

Do not round this up to `yes`.

1. Replace the working claim with the `approved_claim`
2. Record the unsupported parts and missing evidence in `findings.md`
3. Build the **minimum** supplementary experiment package, not a sprawling wishlist
4. Record the failure principle, wrong assumption, and revive condition so later ideation and planning can reuse the lesson
5. Re-run `/result-to-claim` after the supplementary evidence lands

If the same claim reaches `partial` more than `REPEAT_PARTIAL_THRESHOLD` times, escalate with a deeper reviewer follow-up instead of looping blindly:

```text
spawn_agent:
  model: REVIEWER_MODEL
  reasoning_effort: xhigh
  message: |
    REPEATED PARTIAL VERDICT ANALYSIS

    This claim has received multiple partial verdicts.

    Claim history:
    [initial claim + each partial revision]

    Evidence added so far:
    [what was tested after each revision]

    Determine whether we should:
    1. narrow the claim permanently
    2. run one final decisive experiment
    3. stop and pivot

    Return the minimum credible path forward.
```

#### `yes` — claim supported

1. Record the exact approved claim and its boundaries in `CLAIMS_FROM_RESULTS.md`
2. If the verdict came from a provisional local fallback, keep the claim marked provisional and replay the external reviewer before paper writing finalization
2. If ablations or robustness checks are missing, trigger `/ablation-planner`
3. If confidence is only `medium`, treat the claim as provisionally supported and close the biggest gap before paper writing
4. If confidence is `high` and evidence is complete, move to paper planning

### Step 5: Sync to Research Wiki

**Skip entirely if `research-wiki/` does not exist.**

After the verdict:

```bash
python3 tools/research_wiki.py rebuild_query_pack research-wiki/
python3 tools/research_wiki.py log research-wiki/ "result-to-claim: exp:<id> verdict=<verdict>"
```

Also update the relevant `exp:` and `claim:` pages. If the verdict exposed a reusable lesson, write or update a `principle:` page and rebuild all packs so the failure becomes reusable knowledge:

- `yes` → add `supports`
- `partial` → add `supports` with `partial` evidence and record the narrowed scope
- `no` → add `invalidates` and link the failure notes
- if the verdict reveals a reusable principle or revive condition, add `tests_principle` / `revives` edges and rebuild packs with `python3 tools/research_wiki.py rebuild_packs research-wiki/`

If multiple ideas have recently failed or stalled at `partial`, explicitly recommend re-ideation or a `deep-innovation-loop` pivot.

## Rules

- The reviewer judges; the executor routes. Keep those roles separate.
- Never inflate a claim beyond the reviewer-approved scope.
- Low-confidence `yes` is not a paper-ready claim.
- Always preserve negative evidence and unsupported claim fragments in writing.
- Record every verdict in `CLAIMS_FROM_RESULTS.md` and `findings.md`, even when the answer is disappointing.
