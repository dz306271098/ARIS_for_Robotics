---
name: auto-review-loop
description: "Autonomous multi-round research review loop. Repeatedly reviews using Claude Code via claude-review MCP, implements fixes, validates them, and re-reviews until positive assessment or max rounds reached. Use when user says \"auto review loop\", \"review until it passes\", or wants autonomous iterative improvement."
argument-hint: [topic-or-scope]
allowed-tools: Bash(*), Read, Grep, Glob, Write, Edit, Agent
---

> Override for Codex users who want **Claude Code**, not a second Codex agent, to act as the reviewer. Install this package **after** `skills/skills-codex/*`.

# Auto Review Loop: Autonomous Research Improvement

Autonomously iterate: review -> implement fixes -> validate -> re-review, until the external reviewer gives a positive assessment or `MAX_ROUNDS` is reached.

## Context: $ARGUMENTS

## Constants

- **MAX_ROUNDS = 4** — Maximum number of review iterations. Override via argument, e.g. `— max rounds: 8`.
- **POSITIVE_THRESHOLD** — Venue-specific acceptance bar:
  - `RAL/TRO`: overall >= 7/10, no blocking weaknesses, experimental rigor >= 7
  - `ICRA/IROS`: overall >= 7/10, no blocking weaknesses, technical soundness >= 7
  - `CVPR/ICCV/ECCV`: overall >= 7/10, no blocking weaknesses, novelty >= 7
  - `NeurIPS/ICML/ICLR`: overall >= 7/10, no blocking weaknesses
  - default: overall >= 7/10 and no blocking weaknesses
- **REVIEW_DOC = `AUTO_REVIEW.md`** — Cumulative review log in project root.
- **REVIEWER_MODEL = `claude-review`** — Claude reviewer invoked through the local `claude-review` MCP bridge. Set `CLAUDE_REVIEW_MODEL` if you need a specific Claude model override.
- **HUMAN_CHECKPOINT = false** — When `true`, pause after each round's review and wait for user guidance before implementation.
- **COMPACT = false** — When `true`, prefer `EXPERIMENT_LOG.md` and `findings.md` over raw logs during recovery and append one-line findings after each round.
- **RESEARCH_DRIVEN_FIX = true** — When `true`, convert critical weaknesses into root-cause hypotheses, search literature for principles, and choose a fix strategy instead of blindly applying the reviewer's minimum fix.
- **MANDATORY_TEST_GATE = true** — Any round that changes code must pass the shared execution test gate before experiments or re-review. See `../shared-references/execution-test-gate.md`.
- **CONVERGENCE_MEMO_ROUND = 3** — After 3 dispute turns on the same reviewer issue, force a convergence memo.
- **MAX_REVIEW_DISPUTE_ROUNDS = 5** — After 5 dispute turns, stop debating and request a resolution-only action plan. See `../shared-references/reviewer-resolution-protocol.md`.

> Override example: `/auto-review-loop "robot manipulation" — max rounds: 6, compact: true, human checkpoint: true`

## State Persistence

Persist `REVIEW_STATE.json` after every round:

```json
{
  "round": 2,
  "thread_id": "019cd392-...",
  "status": "in_progress",
  "last_score": 5.0,
  "last_verdict": "not_ready",
  "pending_experiments": ["screen_name_1"],
  "timestamp": "2026-03-13T21:00:00"
}
```

On completion, set `"status": "completed"` so future invocations start fresh.

## Workflow

### Initialization

1. Check for `REVIEW_STATE.json`:
   - missing -> fresh start
   - `completed` -> fresh start
   - `in_progress` older than 24 hours -> stale, start fresh
   - `in_progress` within 24 hours -> resume from the next round
2. Read project narrative documents, `AUTO_REVIEW.md`, current results, and recent diffs. When `COMPACT = true`, prefer `findings.md` and `EXPERIMENT_LOG.md` where they exist.
3. Identify the current strongest claim, the latest evidence, and the highest-risk open weaknesses.
4. Create or update `AUTO_REVIEW.md` with a timestamped header.

### Loop

Repeat until the stop condition is met or `MAX_ROUNDS` is exhausted.

#### Phase A: Review

First do a local ground-truth audit before asking the reviewer:

- Read the latest results directly from raw files, not just summaries.
- Inspect the current working tree or recent commits for implementation changes.
- Check for baseline fairness, missing seeds, missing variance reporting, suspicious metrics, and claims unsupported by evidence.
- If you already know a finding is false, collect the evidence now so you can rebut it cleanly in Phase B.

Then send the external reviewer a structured assessment request:

```
mcp__claude-review__review_start:
  prompt: |
    [Round N/MAX_ROUNDS of autonomous review loop]

    Read the project context I provide and act as a strict top-tier ML reviewer.

    Return:
    1. Five dimension scores: novelty, technical_soundness, experimental_rigor, clarity, significance
    2. An overall score from 1-10
    3. `blocking_weaknesses` (must fix)
    4. `strengthening_weaknesses` (nice to have)
    5. A verdict: READY / ALMOST / NOT_READY
    6. For each blocking weakness, the minimum credible fix

    Review standards:
    - attack weak baselines, unfair tuning, weak statistics, cherry-picked metrics, unsupported claims
    - treat missing seeds / missing variance / missing ablation / wrong ground truth usage as severe
    - be explicit and brutal rather than polite

    Context:
    [claims, method summary, datasets, metrics, result tables, recent diffs, prior weaknesses]
```

After this start call, immediately save the returned `jobId` and poll `mcp__claude-review__review_status` with a bounded `waitSeconds` until `done=true`. Treat the completed status payload's `response` as the reviewer output, and save the completed `threadId` for any follow-up round.

If this is round 2+, continue the same reviewer thread:

```
mcp__claude-review__review_reply_start:
  threadId: [saved from round 1]
  prompt: |
    [Round N update]

    Since your last review, we changed:
    1. [change]
    2. [change]
    3. [change]

    Updated metrics:
    [results]

    Re-score with the same format: five dimension scores, overall score, blocking_weaknesses, strengthening_weaknesses, verdict, minimum fixes.
```

After this start call, immediately save the returned `jobId` and poll `mcp__claude-review__review_status` with a bounded `waitSeconds` until `done=true`. Treat the completed status payload's `response` as the reviewer output, and save the completed `threadId` for any follow-up round.

#### Phase B: Parse Assessment

Extract and record:

- five dimension scores
- overall score
- verdict
- blocking weaknesses
- strengthening weaknesses
- ranked action items

Then run **review feedback verification** before implementing anything:

- Confirm each blocking weakness against raw evidence.
- If a finding is correct, keep it.
- If a finding is partially wrong, narrow it to the real issue.
- If a finding is clearly wrong, document the rebuttal with evidence in `AUTO_REVIEW.md` and do not implement a fake fix just to satisfy the reviewer.

#### Phase B.2: Reviewer Dispute Resolution

For every finding, classify it as `accepted`, `narrowed`, `rebutted`, or `unresolved` using the shared **Reviewer Resolution Protocol** from `../shared-references/reviewer-resolution-protocol.md`.

For every `narrowed`, `rebutted`, or `unresolved` item, continue the same reviewer thread with concrete evidence:

```
mcp__claude-review__review_reply_start:
  threadId: [saved reviewer agent id]
  prompt: |
    Re-check only these disputed findings against the actual evidence:

    - disputed item:
    - executor evidence:
    - requested outcome: accept / narrow / withdraw / specify the minimum resolution action

    Do not restate the whole review. Resolve only the listed items.
```

After this start call, immediately save the returned `jobId` and poll `mcp__claude-review__review_status` with a bounded `waitSeconds` until `done=true`. Treat the completed status payload's `response` as the reviewer output, and save the completed `threadId` for any follow-up round.

Rules:

- After `CONVERGENCE_MEMO_ROUND` turns on the same issue, append a `Convergence Memo` to `AUTO_REVIEW.md`.
- After `MAX_REVIEW_DISPUTE_ROUNDS`, stop open-ended argument and request a resolution-only action plan.
- No blocking weakness may proceed into implementation while still unclassified.

**Stop condition**:

- stop immediately if the overall score satisfies `POSITIVE_THRESHOLD` for the target venue and no verified blocking weaknesses remain
- also stop if the verdict explicitly says `READY`

#### Human Checkpoint

Skip entirely if `HUMAN_CHECKPOINT = false`.

When enabled, present the round score, top weaknesses, and planned fixes. Wait for the user to continue, modify, skip, or stop.

#### Feishu Notification

If `~/.codex/feishu.json` exists and mode is not `"off"`, send a `review_scored` notification with the round score, verdict, and top weaknesses.

#### Phase B.5: Research-Driven Fix Design

Skip entirely if `RESEARCH_DRIVEN_FIX = false`.

For each verified blocking weakness:

1. Classify it as symptom vs root cause.
2. If the root cause is novel or not already addressed in prior rounds:
   - search literature for mechanisms that address the same root cause
   - prefer principles over copied methods
   - use adjacent domains when the local literature is thin
3. Produce 2-3 strategies:
   - minimal fix
   - principle-inspired stronger fix
   - optional fused strategy when two principles combine naturally
4. Select the strategy that best balances:
   - expected improvement
   - implementation cost
   - integration cleanliness
   - novelty impact

If a root cause has already failed in prior rounds, do not repeat the same fix family.

#### Phase C: Implement Fixes

For each highest-priority verified weakness:

1. Implement the chosen fix in code, analysis, or framing.
2. Run a strict local code-and-evidence audit before launching new experiments:
   - correct logic
   - fair baseline comparison
   - fixed seeds
   - correct metrics
   - evaluation against dataset ground truth, never another model's output
3. For changed hyperparameters, run a quick sensitivity sweep on the smallest viable setup before committing to full runs.
4. Launch the best candidate with at least 3 seeds when the experiment is stochastic.
5. If W&B is available, invoke `/training-check` during longer runs.

Prioritization rules:

- prefer metric additions, reframing, and targeted ablations when they solve the concern cheaply
- skip fixes that require unavailable data or infrastructure
- do not burn major GPU budget until the implementation and small-scale validation look credible

#### Phase C.4: Mandatory Test Gate

Before launching experiments or moving to re-review, execute the shared **Mandatory Test Gate** from `../shared-references/execution-test-gate.md`.

Requirements:

1. Build a **Change Map** for every changed module, entrypoint, config, and result path.
2. Run at least one **module test** per changed module.
3. If the project has no relevant tests yet, add the smallest credible module test first.
4. Run a **workflow smoke test** on the smallest real end-to-end path touched by the fix.
5. Record the evidence directly in `AUTO_REVIEW.md`.

Static inspection is not enough. A failed test gate blocks the next review round.

#### Phase C.5: Validate the Fix

Do not advance to the next review round until validation passes.

Validation requirements:

1. Compute mean +/- std across seeds for the changed experiment.
2. When the delta is close to noise, run a significance test or explicitly mark the result inconclusive.
3. Verify the fix addressed the targeted weakness, not just some unrelated metric.
4. Check for regressions elsewhere: fairness, runtime, stability, clarity, or added complexity.
5. If the fix is not statistically credible or does not address the root cause, try the next strategy instead of rushing to re-review.

#### Phase D: Wait and Collect

If experiments are running:

- monitor sessions and result files
- collect raw metrics and derived summaries
- update figures/tables if the review item required presentation changes
- keep `pending_experiments` in `REVIEW_STATE.json` accurate

#### Phase E: Document the Round

Append to `AUTO_REVIEW.md`:

```markdown
## Round N (timestamp)

### Assessment
- Scores: novelty X, soundness Y, rigor Z, clarity A, significance B
- Overall: O/10
- Verdict: READY / ALMOST / NOT_READY
- Verified blocking weaknesses:
  - [...]

### Feedback Verification
- accepted:
  - [...]
- narrowed:
  - [...]
- rebutted:
  - [...]
- unresolved:
  - [...]

### Convergence Memo
- settled:
- contested:
- unknown:
- minimum resolution path:

### Strategy Chosen
- root cause:
- selected strategy:
- rejected strategies:

### Actions Taken
- [...]

### Mandatory Test Gate
- change map:
- module tests:
- workflow smoke test:
- gate status:

### Results
- mean +/- std:
- significance:
- did the targeted weakness improve:

### Status
- continue / stop
```

When `COMPACT = true`, also append a one-line summary to `findings.md`.

Write `REVIEW_STATE.json` after every round.

### Termination

When the loop ends:

1. Mark `REVIEW_STATE.json` as completed.
2. Write a final summary in `AUTO_REVIEW.md`.
3. Add a concise `## Method Description` section to `AUTO_REVIEW.md` so downstream paper and illustration skills can reuse it.
4. Invoke `/result-to-claim` so the final evidence is turned into defensible paper claims.
5. If max rounds were exhausted without a pass:
   - list remaining blockers
   - estimate effort to clear each blocker
   - say whether the right next step is continue, narrow claims, or pivot

## Key Rules

- Be honest. Negative results and failed fixes belong in the record.
- Do not hide weaknesses to game a positive score.
- Do not implement reviewer suggestions mechanically when the evidence contradicts them.
- Every substantial fix must be validated before the next review round.
- Favor root-cause repair over cosmetic patching.
- Document enough that a new session can resume from `AUTO_REVIEW.md` and `REVIEW_STATE.json` without re-reading the full history.
