---
name: "research-review"
description: "Get a deep critical review of research from GPT using a secondary Codex reviewer agent. Use when you want hard feedback on ideas, drafts, experiments, or overall research positioning."
allowed-tools: Bash(*), Read, Grep, Glob, Write, Edit, Agent
argument-hint: [topic-or-scope]
---

> Override for Codex users who want **Claude Code**, not a second Codex agent, to act as the reviewer. Install this package **after** `skills/skills-codex/*`.

# Research Review via a Secondary Codex Reviewer

Get a multi-round external review with maximum rigor, but keep the executor local.

## Constants

- **REVIEWER_MODEL = `claude-review`** — Claude reviewer invoked through the local `claude-review` MCP bridge. Set `CLAUDE_REVIEW_MODEL` if you need a specific Claude model override.
- **MAX_REVIEW_ROUNDS = 5** — After that, force an agreement checkpoint instead of open-ended discussion
- **AUTONOMY_PROFILE = `CODEX.md -> ## Autonomy Profile`** — Source of reviewer fallback policy in unattended-safe mode.
- **AUTONOMY_STATE = `AUTONOMY_STATE.json`** — Cross-workflow state anchor for review progress, provisional fallback, and replay requirements.

## Context: $ARGUMENTS

## Prerequisites

- Install the base Codex-native skills first: copy `skills/skills-codex/*` into `~/.codex/skills/`.
- Then install this overlay package: copy `skills/skills-codex-claude-review/*` into `~/.codex/skills/` and allow it to overwrite the same skill names.
- Register the local reviewer bridge:
  ```bash
  codex mcp add claude-review -- python3 ~/.codex/mcp-servers/claude-review/server.py
  ```
- This gives Codex access to `mcp__claude-review__review_start`, `mcp__claude-review__review_reply_start`, and `mcp__claude-review__review_status`.


## Unattended Safe Mode

When `CODEX.md -> ## Autonomy Profile` sets `autonomy_mode: unattended_safe`:

- retry the external reviewer path first according to `max_reviewer_runtime_retries`
- if `review_fallback_mode: retry_then_local_critic`, a local critical pass may keep execution moving but must set `review_mode=local_fallback` and `review_replay_required=true`
- do not clear a review-dependent blocker or mark the stage completed until the external review thread has been replayed successfully

## Workflow

### Step 1: Build a Real Review Brief

Before asking for criticism, gather the actual state of the project:

1. Narrative documents: `README.md`, `NARRATIVE_REPORT.md`, `STORY.md`, paper drafts
2. Method and experiment artifacts: `refine-logs/`, `innovation-logs/`, result tables, W&B summaries
3. Implementation constraints: `CODEX.md`, `RESEARCH_BRIEF.md`, compute limits, available baselines
4. Known weaknesses: prior review docs, `findings.md`, failed experiments, novelty-check output

Write a self-contained `RESEARCH_REVIEW.md` scaffold with:

- project summary
- intended claims
- strongest evidence
- known weaknesses
- concrete questions for the reviewer

### Step 2: Initial External Review

Send a full briefing, not a vague prompt.

```
mcp__claude-review__review_start:
  prompt: |
    SENIOR RESEARCH REVIEW

    Please act as a demanding top-tier reviewer for this project.

    Research context:
    [problem, method, target venue, constraints]

    Core claims:
    [3-5 claims]

    Evidence:
    [main results, ablations, novelty positioning, limitations]

    Known weaknesses:
    [what already looks shaky]

    Return:
    1. overall_score: 1-10
    2. dimension_scores: novelty | technical_soundness | experimental_rigor | clarity | significance
    3. strongest_points: ranked list
    4. critical_weaknesses: ranked list
    5. missing_experiments: minimum package, not a wishlist
    6. claim_risks: which claims are weak or overstated
    7. narrative_risks: what a reviewer will misunderstand or dismiss
    8. venue_fit: accept frontier | borderline | weak fit
    9. highest_leverage_next_step: one action that changes the outcome most

    Be specific, skeptical, and evidence-driven.
```

After this start call, immediately save the returned `jobId` and poll `mcp__claude-review__review_status` with a bounded `waitSeconds` until `done=true`. Treat the completed status payload's `response` as the reviewer output, and save the completed `threadId` for any follow-up round.

Save the raw reviewer output into `RESEARCH_REVIEW.md`.

### Step 3: Iterative Dialogue

Use follow-up rounds to resolve the highest-value disagreements, not to argue defensively.

Typical follow-ups:

- ask whether a reframed claim would now be acceptable
- request the minimum experiment package that resolves a specific objection
- request a claims-to-evidence matrix
- ask for a mock venue review with score and confidence
- ask which single weakness most threatens rejection

Use the same reviewer thread for continuity:

```
mcp__claude-review__review_reply_start:
  threadId: [saved agent id]
  prompt: |
    Follow-up on the previous review.

    Here is the clarification / new evidence:
    [reply with specific evidence]

    Re-evaluate only these points:
    [contested claims, experiments, narrative structure]
```

After this start call, immediately save the returned `jobId` and poll `mcp__claude-review__review_status` with a bounded `waitSeconds` until `done=true`. Treat the completed status payload's `response` as the reviewer output, and save the completed `threadId` for any follow-up round.

### Step 4: Convergence Memo / Agreement Checkpoint

After round 3, or earlier if the discussion starts circling, force a convergence memo inside `RESEARCH_REVIEW.md`. This is the reference form for the shared reviewer-resolution pattern used by the execution loops:

```markdown
## Agreement Checkpoint

- Settled:
  [claims and evidence both sides now accept]
- Contested:
  [specific disagreements and why they remain unresolved]
- Unknown:
  [things that still require experiment or analysis]
- Resolution path:
  [one concrete action per contested or unknown item]
```

If contested items remain after `MAX_REVIEW_ROUNDS`, stop debating and switch to a resolution-oriented follow-up:

```
mcp__claude-review__review_reply_start:
  threadId: [saved agent id]
  prompt: |
    We need to converge.

    Here are the remaining contested items:
    [list]

    For each item, specify the minimum experiment, analysis, or claim change that resolves it.
    Do not restate the whole review. Produce an action plan only.
```

After this start call, immediately save the returned `jobId` and poll `mcp__claude-review__review_status` with a bounded `waitSeconds` until `done=true`. Treat the completed status payload's `response` as the reviewer output, and save the completed `threadId` for any follow-up round.

### Step 5: Final Deliverables

Finalize `RESEARCH_REVIEW.md` with:

- round-by-round summary
- final score and dimension scores
- settled claims
- contested claims
- claims-evidence matrix
- prioritized TODOs with estimated compute or writing cost
- optional paper outline or mock review if requested

Also update `findings.md`, `CODEX.md`, or project notes with the small number of review conclusions that should actually steer execution.

## Key Rules

- Always ask for high-rigor review; shallow politeness is useless here.
- Give the reviewer the strongest opposing evidence too, not just the polished story.
- Do not let the reviewer become the executor. The reviewer critiques; the executor decides and implements.
- Force convergence with an agreement checkpoint when the dialogue starts repeating.
- Preserve both the raw review output and the normalized action items.
