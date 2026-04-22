---
name: "rebuttal"
description: "Workflow 4: Submission rebuttal pipeline. Parses external reviews, enforces coverage and grounding, drafts a safe rebuttal under venue limits, and manages follow-up rounds."
allowed-tools: Bash(*), Read, Grep, Glob, Write, Edit, Agent, Skill, mcp__gemini_review__review_start, mcp__gemini_review__review_reply_start, mcp__gemini_review__review_status
argument-hint: [paper-path-or-review-bundle]
---

> Override for Codex users who want **Gemini CLI**, not a second Codex agent, to act as the reviewer. Install this package **after** `skills/skills-codex/*`.

# Workflow 4: Rebuttal

Prepare and maintain a grounded, venue-compliant rebuttal for: **$ARGUMENTS**

## Scope

This skill is optimized for:

- text-only rebuttals with hard limits
- multiple reviewers with overlapping concerns
- follow-up rounds after the first response
- grounded drafting with zero fabrication and explicit issue tracking

This skill does **not**:

- invent experiments or derivations
- promise unapproved work
- edit or submit the final conference system entry for the user

## Lifecycle Position

```text
Workflow 1:   idea-discovery
Workflow 1.5: experiment-bridge
Workflow 2:   auto-review-loop
Workflow 3:   paper-writing
Workflow 4:   rebuttal
```

## Constants

- **VENUE = `ICML`**
- **RESPONSE_MODE = `TEXT_ONLY`**
- **REVIEWER_MODEL = `gemini-review`** — Gemini reviewer invoked through the local `gemini-review` MCP bridge. This bridge is CLI-first; set `GEMINI_REVIEW_MODEL` if you need a specific Gemini CLI model override.
- **MAX_INTERNAL_DRAFT_ROUNDS = 2**
- **MAX_STRESS_TEST_ROUNDS = 1**
- **MAX_FOLLOWUP_ROUNDS = 3**
- **AUTO_EXPERIMENT = true** — Default restored: if reviewers need new evidence and the timeline allows it, automatically bridge into supplementary experiments
- **QUICK_MODE = false**
- **REBUTTAL_DIR = `rebuttal/`**
- **MANDATORY_TEST_GATE = true** — Any code written for rebuttal evidence must pass the shared execution test gate through `/experiment-bridge`. See `../shared-references/execution-test-gate.md`.
- **REVIEWER_RESOLUTION_PROTOCOL = true** — Disputed stress-test findings must go back through the same reviewer dialogue until they are accepted, narrowed, rebutted, or converted into a minimum action. See `../shared-references/reviewer-resolution-protocol.md`.

> Override example: `/rebuttal "paper/ + reviews" — venue: NeurIPS, character limit: 5000`

## Required Inputs

1. paper source: PDF, LaTeX, or structured narrative
2. raw reviews: pasted text, markdown, or PDF
3. venue rules: limit, format, revised-PDF policy
4. current stage: first response or follow-up

If venue rules or limit are missing, stop and ask before drafting.

## Safety Model

Three hard gates. If any one fails, do not finalize.

1. **Provenance gate** — every factual statement must map to `paper`, `review`, `user_confirmed_result`, `user_confirmed_derivation`, or `future_work`
2. **Commitment gate** — every promise must be `already_done`, `approved_for_rebuttal`, or `future_work_only`
3. **Coverage gate** — every reviewer concern must end in `answered`, `deferred_intentionally`, or `needs_user_input`

## Workflow

### Phase 0: Resume or Initialize

1. If `rebuttal/REBUTTAL_STATE.md` exists, resume from it
2. Otherwise create `rebuttal/` and initialize the working files
3. Load paper, reviews, venue rules, and any already-approved new evidence

### Phase 1: Normalize Reviews

Create `rebuttal/REVIEWS_RAW.md` with the raw review text verbatim.

Record metadata in `rebuttal/REBUTTAL_STATE.md`:

- venue
- limit
- response format
- round
- available evidence
- blocked evidence requests

### Phase 2: Atomize Reviewer Concerns

Create `rebuttal/ISSUE_BOARD.md`.

For each atomic concern, record:

- `issue_id` such as `R1-C2`
- reviewer and round
- short raw anchor quote
- `issue_type`: assumptions / theorem_rigor / novelty / empirical_support / baseline_comparison / complexity / significance / clarity / reproducibility / other
- `severity`: critical / major / minor
- `reviewer_stance`: positive / swing / negative / unknown
- `response_mode`: direct_clarification / grounded_evidence / nearest_work_delta / assumption_hierarchy / narrow_concession / future_work_boundary
- `status`: open / answered / deferred / needs_user_input

No issue is allowed to disappear between phases.

### Phase 3: Build the Strategy Plan

Create `rebuttal/STRATEGY_PLAN.md`.

It must include:

1. 2-4 global themes that resolve shared concerns
2. a response mode per issue
3. a character budget by section
4. blocked claims or blocked promises
5. evidence gaps that require either experiment, derivation, or concession

If `QUICK_MODE = true`, stop here and present `ISSUE_BOARD.md` plus `STRATEGY_PLAN.md`.

### Phase 3.5: Evidence Sprint

If the strategy plan shows that reviewer concerns require new empirical evidence and `AUTO_EXPERIMENT = true`, automatically create `rebuttal/REBUTTAL_EXPERIMENT_PLAN.md` and invoke:

```text
/experiment-bridge "rebuttal/REBUTTAL_EXPERIMENT_PLAN.md"
```

Do not bypass `/experiment-bridge` with ad-hoc rebuttal code changes. The supplementary code path must still pass the **Mandatory Test Gate** and produce executable evidence before the rebuttal can cite it.

Use it only for concise, rebuttal-oriented experiments:

- missing baseline comparison
- missing ablation
- missing robustness or scale check
- missing failure-case quantification

If experiments fail or remain inconclusive:

- do not fabricate a win
- change the response mode to `narrow_concession` or `future_work_boundary`
- record the outcome in `rebuttal/REBUTTAL_EXPERIMENTS.md`

If `AUTO_EXPERIMENT = false`, pause and present the evidence gaps instead of running them.

### Phase 4: Draft the Rebuttal

Create `rebuttal/REBUTTAL_DRAFT_v1.md` and `rebuttal/PASTE_READY.txt`.

Default structure:

1. short opener with 2-4 global resolutions
2. per-reviewer numbered responses
3. short closing for the meta-reviewer

Default response pattern per issue:

- sentence 1: direct answer
- sentence 2-4: grounded evidence
- final sentence: implication for the paper or what was clarified

Drafting heuristics:

- evidence beats rhetoric
- shared concerns belong in the opener
- novelty disputes should name the closest work and the exact delta
- theory disputes should separate core assumptions from technical assumptions
- if the reviewer is correct, concede narrowly and move on
- answer supportive reviewers too; do not ignore favorable framing

### Phase 5: Safety Validation

Run all lints before finalizing:

1. coverage
2. provenance
3. commitment
4. tone
5. consistency
6. limit

If over limit, compress in this order:

1. redundancy
2. soft phrasing
3. opener length
4. sentence-level wording

Never drop a critical answer to save characters.

### Phase 6: External Stress Test

Run a reviewer stress test on the draft:

```
mcp__gemini_review__review_start:
  prompt: |
    REBUTTAL STRESS TEST

    Reviews:
    [raw reviews]

    Issue board:
    [normalized concerns]

    Draft:
    [current rebuttal]

    Venue rules:
    [limit and format]

    Return:
    1. verdict: safe_to_submit | needs_revision
    2. unanswered_concerns: ranked list
    3. unsupported_statements: ranked list
    4. risky_promises: ranked list
    5. tone_risks: ranked list
    6. most_dangerous_paragraph: quote + reason
    7. minimal_grounded_fixes: concrete edits only

    Do not invent evidence.
```

After this review-start or review-reply call, immediately save the returned `jobId` and poll `mcp__gemini_review__review_status` with a bounded `waitSeconds` until `done=true`. Treat the completed status payload's `response` as the reviewer output, and save the completed `threadId` for any follow-up round.

Save the raw output to `rebuttal/CODEX_STRESS_TEST.md`.

Apply the shared **Reviewer Resolution Protocol** to the stress-test findings:

- classify each finding as `accepted`, `narrowed`, `rebutted`, or `unresolved`
- for `narrowed`, `rebutted`, or `unresolved` items, continue the same reviewer thread with concrete evidence only
- after 3 rounds on the same disputed point, append a `Convergence Memo` to `rebuttal/CODEX_STRESS_TEST.md`
- at `MAX_FOLLOWUP_ROUNDS`, stop open-ended argument and request the minimum grounded resolution only

No disputed blocker is allowed to stay as vague reviewer disagreement.

If you revise the draft and want one more bounded pass, reuse the same reviewer thread:

```
mcp__gemini_review__review_reply_start:
  threadId: [saved completed `threadId`]
  prompt: |
    Here is the revised rebuttal draft after applying your fixes.
    Re-check only unresolved blockers and confirm whether it is now safe to submit.
```

After this review-start or review-reply call, immediately save the returned `jobId` and poll `mcp__gemini_review__review_status` with a bounded `waitSeconds` until `done=true`. Treat the completed status payload's `response` as the reviewer output, and save the completed `threadId` for any follow-up round.

### Phase 7: Finalize Two Deliverables

Produce:

1. **`rebuttal/PASTE_READY.txt`** — strict venue-compliant version
2. **`rebuttal/REBUTTAL_DRAFT_rich.md`** — richer version with optional sections marked `[OPTIONAL - cut if over limit]`

Update `rebuttal/REBUTTAL_STATE.md` with:

- current phase
- final character count
- remaining manual approvals
- unresolved risks

### Phase 8: Follow-Up Rounds

When new comments arrive:

1. append them verbatim to `rebuttal/FOLLOWUP_LOG.md`
2. map each comment to an old or new issue
3. write a delta reply only
4. rerun safety lints
5. if continuity helps, reuse the same reviewer thread via `mcp__gemini_review__review_reply_start` plus `mcp__gemini_review__review_status`

## Key Rules

- Never fabricate evidence, numbers, derivations, citations, or links.
- Never promise work the user has not approved.
- Keep every issue visible from raw review to final answer.
- Preserve raw records and reviewer outputs verbatim.
- Prefer narrow honest concessions over broad evasions.
- Do not waste rebuttal budget on unwinnable arguments.
- Respect the hard venue limit.
- Do not cite new empirical evidence unless the supporting code path passed the Mandatory Test Gate.
