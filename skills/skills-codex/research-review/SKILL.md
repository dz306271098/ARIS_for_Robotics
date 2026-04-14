---
name: "research-review"
description: "Get a deep critical review of research from GPT using a secondary Codex reviewer agent. Use when you want hard feedback on ideas, drafts, experiments, or overall research positioning."
allowed-tools: Bash(*), Read, Grep, Glob, Write, Edit, Agent
argument-hint: [topic-or-scope]
---


# Research Review via a Secondary Codex Reviewer

Get a multi-round external review with maximum rigor, but keep the executor local.

## Constants

- **REVIEWER_MODEL = `gpt-5.4`** — Reviewer model used through a secondary Codex agent
- **MAX_REVIEW_ROUNDS = 5** — After that, force an agreement checkpoint instead of open-ended discussion

## Context: $ARGUMENTS

## Prerequisites

- Use `spawn_agent` and `send_input` when delegation is allowed.
- If delegation is unavailable, run the same structure locally and mark the output `[pending external review]`.

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

```text
spawn_agent:
  model: REVIEWER_MODEL
  reasoning_effort: xhigh
  message: |
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

```text
send_input:
  target: [saved agent id]
  message: |
    Follow-up on the previous review.

    Here is the clarification / new evidence:
    [reply with specific evidence]

    Re-evaluate only these points:
    [contested claims, experiments, narrative structure]
```

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

```text
send_input:
  target: [saved agent id]
  message: |
    We need to converge.

    Here are the remaining contested items:
    [list]

    For each item, specify the minimum experiment, analysis, or claim change that resolves it.
    Do not restate the whole review. Produce an action plan only.
```

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
