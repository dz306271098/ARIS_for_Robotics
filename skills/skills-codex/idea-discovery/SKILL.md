---
name: "idea-discovery"
description: "Workflow 1: Full idea discovery pipeline. Orchestrates research-lit → idea-creator → novelty-check → research-review → research-refine-pipeline to go from a broad direction to a validated, ranked, and refinement-ready idea set."
allowed-tools: Bash(*), Read, Write, Edit, Grep, Glob, WebSearch, WebFetch, Agent, Skill
argument-hint: [research-direction]
---


# Workflow 1: Idea Discovery Pipeline

Orchestrate a complete idea discovery workflow for: **$ARGUMENTS**

## Overview

This pipeline chains:

```text
/research-lit -> /idea-creator -> /novelty-check -> /research-review -> /research-refine-pipeline
```

The end state is not just "some ideas." It is:

- a ranked `IDEA_REPORT.md`
- a refinement-ready top idea
- `refine-logs/FINAL_PROPOSAL.md`
- `refine-logs/EXPERIMENT_PLAN.md`

## Constants

- **PILOT_MAX_HOURS = 2**
- **PILOT_TIMEOUT_HOURS = 3**
- **MAX_PILOT_IDEAS = 3**
- **MAX_TOTAL_GPU_HOURS = 8**
- **AUTO_PROCEED = true** — default remains aggressive; if the user does not intervene, continue with the best option
- **REVIEWER_MODEL = `gpt-5.4`** — passed through to reviewer-aware downstream skills
- **ARXIV_DOWNLOAD = false**
- **COMPACT = false** — when true, also write `IDEA_CANDIDATES.md`
- **REF_PAPER = false**

## Pipeline

### Phase 0: Load the Research Anchor

Before searching or brainstorming, load the richest available project context:

1. `RESEARCH_BRIEF.md` if present
2. `CODEX.md` if present
3. `research-wiki/query_pack.md` if present
4. any user-supplied one-line direction in `$ARGUMENTS`

Extract:

- problem framing
- constraints: compute, data, timeline, venue
- already-tried ideas and failures
- non-goals
- target contribution style

Treat this as the project anchor for all later phases. If both a brief and `$ARGUMENTS` exist, the brief supplies details and `$ARGUMENTS` supplies directional emphasis.

### Phase 0.5: Reference Paper Summary

**Skip if `REF_PAPER = false`.**

If a reference paper is supplied:

1. fetch or read it
2. summarize its core method, results, limitations, and open opportunities
3. write `REF_PAPER_SUMMARY.md`

Use that summary during literature search and idea generation so the pipeline can propose genuine improvements instead of shallow copies.

### Phase 1: Literature Survey

Invoke `/research-lit` with the anchored direction.

Goals:

- map the landscape
- identify saturated subspaces
- identify open gaps
- identify reusable mechanisms from adjacent domains

If `research-wiki/query_pack.md` exists, feed it in as prior memory so repeated failures become an anti-pattern list rather than forgotten history.

Checkpoint behavior:

- summarize the top gaps and candidate directions
- if `AUTO_PROCEED = true`, continue immediately with the highest-leverage direction
- if `AUTO_PROCEED = false`, wait for user confirmation or scope changes

### Phase 2: Idea Generation, Filtering, and Pilots

Invoke `/idea-creator` with:

- the Phase 1 landscape
- the project anchor
- `REF_PAPER_SUMMARY.md` if available

This phase should:

- generate 8-12 ideas
- filter by feasibility and compute
- perform lightweight novelty pressure
- run quick pilots for the strongest few ideas when practical
- rank by empirical signal, not by elegance alone

Checkpoint behavior:

- present the top ideas and pilot signals
- if the user is unhappy, regenerate with sharper constraints
- if no response and `AUTO_PROCEED = true`, keep moving with the strongest surviving ideas

### Phase 3: Deep Novelty Verification

For each top candidate with positive or promising signal, run `/novelty-check`.

Update `IDEA_REPORT.md` with:

- closest prior work
- novelty risk level
- honest differentiation

Eliminate ideas that fail deep novelty.

### Phase 4: External Critical Review

For the surviving ideas, run `/research-review`.

This phase should answer:

- is the idea actually interesting to reviewers
- what is the minimum evidence package
- what claim shape is defensible
- what fatal weaknesses remain

Update `IDEA_REPORT.md` with the review outcome and the recommended next action.

### Phase 4.5: Method Refinement and Experiment Planning

Run `/research-refine-pipeline` on the best surviving idea.

Expected outputs:

- `refine-logs/FINAL_PROPOSAL.md`
- `refine-logs/EXPERIMENT_PLAN.md`
- `refine-logs/EXPERIMENT_TRACKER.md`

If the reviewer outcome is weak, allow a lighter path:

- refine the idea
- document risks
- avoid pretending the experiment plan is mature when it is not

### Phase 5: Final Report

Finalize `IDEA_REPORT.md` with:

- executive summary
- literature landscape
- ranked ideas
- eliminated ideas and why they died
- novelty review summary
- external review summary
- refined proposal and experiment plan for the winner
- next execution steps

If `COMPACT = true`, also write `IDEA_CANDIDATES.md` with only the top surviving ideas and the active recommendation.

## Research Wiki Embedding

If `research-wiki/` exists, integrate it into the pipeline instead of treating it as optional decoration:

- Phase 0: use `query_pack.md` as prior memory
- Phase 1: record landscape updates and failed directions
- Phase 2: log top ideas and eliminated ideas
- Phase 3: write novelty verdicts back to the relevant idea pages
- Phase 4.5: link the winning idea to the refined proposal and experiment plan

Rebuild the query pack after major state changes:

```bash
python3 tools/research_wiki.py rebuild_query_pack research-wiki/
```

## Key Rules

- Do not skip phases. Each one kills bad ideas earlier and cheaper.
- Empirical signal beats aesthetic cleverness.
- Keep the pipeline moving unless the user explicitly wants checkpoints to block.
- Preserve eliminated ideas and why they failed.
- Use the project anchor to stop drift into irrelevant but fashionable directions.
- The winning idea should exit this workflow with a concrete next-step plan, not just praise.
