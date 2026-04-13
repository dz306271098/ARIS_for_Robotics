---
name: "research-pipeline"
description: "Full research pipeline: Workflow 1 (idea discovery) -> implementation -> method evolution -> review polish. Goes from a broad research direction all the way to a submission-ready paper. Use when user says \"全流程\", \"full pipeline\", \"从找idea到投稿\", \"end-to-end research\", or wants the complete autonomous research lifecycle."
argument-hint: [research-direction]
allowed-tools: Bash(*), Read, Write, Edit, Grep, Glob, WebSearch, WebFetch, Agent, Skill
---

# Full Research Pipeline: Idea -> Experiments -> Submission

End-to-end autonomous research workflow for: **$ARGUMENTS**

## Constants

- **AUTO_PROCEED = true** — When `true`, Gate 1 auto-selects the top-ranked idea and continues. When `false`, always wait for explicit confirmation.
- **ARXIV_DOWNLOAD = false** — When `true`, `/research-lit` downloads the top relevant arXiv PDFs during literature survey.
- **HUMAN_CHECKPOINT = false** — When `true`, review-style loops pause after each round so the user can modify the plan before fixes are implemented.
- **RESEARCH_WIKI = auto** — `auto`: use `research-wiki/` if it already exists. `true`: initialize it if missing, then keep it in the loop. `false`: ignore wiki integration even if the directory exists.
- **DEEP_INNOVATION = auto** — `auto`: after initial experiments, run an innovation gate and invoke `/deep-innovation-loop` when structural headroom remains. `true`: always run `/deep-innovation-loop` before final review polish. `false`: skip deep innovation and go directly to `/auto-review-loop`.
- **META_OPTIMIZE = false** — When `true`, finish with a report-only `/meta-optimize` pass for harness maintenance. Never auto-apply patches.

> 💡 Override via argument, e.g. `/research-pipeline "topic" — AUTO_PROCEED: false, DEEP_INNOVATION: true, RESEARCH_WIKI: true`.

## Full Autonomy Principle

This pipeline is designed to run with minimal supervision:

1. **Never block without reason** — if enough evidence exists to make a defensible choice, make it and log the reasoning.
2. **Auto-select at forks** — idea choice, implementation path, and innovation/polish routing should be based on evidence, not hesitation.
3. **Auto-recover** — when experiments fail, diagnose, fix, and retry before declaring a hard blocker.
4. **Use durable memory when available** — `CODEX.md`, `research-wiki/`, `refine-logs/`, `AUTO_REVIEW.md`, and `innovation-logs/` are part of the working state, not optional afterthoughts.
5. **Log autonomous decisions** — write `[AUTO-DECISION]` notes into the relevant artifact whenever the pipeline chooses a path on the user's behalf.

## Overview

The mainline path is now:

```text
/idea-discovery -> implement -> /run-experiment -> innovation gate -> /deep-innovation-loop? -> /auto-review-loop -> submission-ready
```

Sidecar systems that should stay attached to this mainline:

- **Research Wiki** — long-horizon memory for papers, ideas, experiments, and claims
- **Meta Optimize** — maintenance loop for improving the harness after enough project evidence accumulates

## Pipeline

### Stage 0: Project Memory Setup

Before launching the main research work, handle durable memory.

**Research Wiki routing**

- If `RESEARCH_WIKI = true` and `research-wiki/` does not exist, initialize it:
  ```text
  /research-wiki init
  ```
- If `RESEARCH_WIKI = auto` and `research-wiki/` exists, use it automatically.
- If `research-wiki/query_pack.md` is missing or obviously stale, rebuild it before ideation:
  ```bash
  python3 tools/research_wiki.py rebuild_query_pack research-wiki/
  ```

Use `CODEX.md` plus `RESEARCH_BRIEF.md` as the authoritative project context. If both exist, treat `CODEX.md` as the project dashboard and `RESEARCH_BRIEF.md` as richer problem context.

### Stage 1: Idea Discovery (Workflow 1)

If `RESEARCH_BRIEF.md` exists in the project root, load it as detailed context.

Invoke:

```text
/idea-discovery "$ARGUMENTS"
```

This internally runs:

```text
/research-lit -> /idea-creator -> /novelty-check -> /research-review -> /research-refine-pipeline
```

**Primary outputs**

- `IDEA_REPORT.md`
- `refine-logs/FINAL_PROPOSAL.md`
- `refine-logs/EXPERIMENT_PLAN.md`
- `refine-logs/EXPERIMENT_TRACKER.md`

**Gate 1**

After `IDEA_REPORT.md` is ready:

- If `AUTO_PROCEED = false`, wait for explicit idea selection.
- If `AUTO_PROCEED = true`, present the ranking, wait briefly for user input, then auto-select the best evidence-backed idea.

If `research-wiki/` is enabled, Stage 1 should already:

- ingest relevant papers via `/research-lit`
- read `query_pack.md` before ideation
- write recommended and killed ideas back into `research-wiki/ideas/`

### Stage 2: Implementation

Once the idea is chosen:

1. Read the selected idea and refined proposal from `IDEA_REPORT.md` and `refine-logs/`.
2. Implement the full experiment:
   - scale pilot code to full experiments
   - expose hyperparameters cleanly
   - add metrics, logs, and result serialization
   - follow the project codebase conventions
3. Perform a local code sanity review before deployment.

### Stage 3: Deploy Experiments

Deploy the initial experiment suite:

```text
/run-experiment [experiment command]
```

Monitor and collect:

```text
/monitor-experiment [server]
```

At the end of Stage 3, you should have enough evidence to decide whether the project needs deep method evolution or only review-driven polish.

### Stage 4: Method Evolution Gate

This stage is now part of the mainline workflow.

#### Case A: `DEEP_INNOVATION = true`

Always invoke:

```text
/deep-innovation-loop "$ARGUMENTS — [chosen idea title]" — baseline: [PRIMARY_BASELINE], venue: [VENUE]
```

Then run a shorter paper-level polish loop:

```text
/auto-review-loop "$ARGUMENTS — [chosen idea title] — post deep innovation polish"
```

#### Case B: `DEEP_INNOVATION = auto` (default)

Run an **innovation gate** after initial experiments. Enter `/deep-innovation-loop` if any of these are true:

- the initial result is negative, weak, or inconclusive
- the intended claim is still not well supported
- weaknesses are structural rather than cosmetic
- the top idea clearly has novelty headroom but the current method realization is not exploiting it
- the project is long-horizon and should accumulate `innovation-logs/` rather than stop at a quick polish loop

If the project already looks strong and mainly needs paper-level tightening, log:

```text
[AUTO-DECISION] Skipping deep innovation because the main claim is already supported and remaining issues are primarily review-polish items.
```

Then go directly to:

```text
/auto-review-loop "$ARGUMENTS — [chosen idea title]"
```

If the gate decides the method still needs structural evolution, invoke:

```text
/deep-innovation-loop "$ARGUMENTS — [chosen idea title]" — baseline: [PRIMARY_BASELINE], venue: [VENUE]
```

and follow it with:

```text
/auto-review-loop "$ARGUMENTS — [chosen idea title] — post deep innovation polish"
```

#### Case C: `DEEP_INNOVATION = false`

Skip deep innovation and go directly to:

```text
/auto-review-loop "$ARGUMENTS — [chosen idea title]"
```

### Stage 5: Final Summary

After the method-evolution stage and final review polish, write a final status report:

```markdown
# Research Pipeline Report

**Direction**: $ARGUMENTS
**Chosen Idea**: [title]
**Date**: [start] -> [end]
**Pipeline**: idea-discovery -> implement -> run-experiment -> deep-innovation? -> auto-review-loop

## Journey Summary
- Ideas generated: X -> filtered to Y -> piloted Z -> chose 1
- Implementation: [what was built]
- Experiments: [number of runs, total compute time]
- Deep innovation: [skipped / auto-entered / forced], rounds: [N]
- Final review rounds: [N], final score: [X/10]

## Durable Memory
- CODEX.md Pipeline Status updated: [yes/no]
- Research Wiki updated: [yes/no]
- Key artifacts: [list]

## Final Status
- [ ] Ready for submission
- [ ] Needs manual follow-up

## Remaining TODOs
- [items]
```

### Stage 5.5: Harness Maintenance (Optional)

If `META_OPTIMIZE = true`, or if the project has accumulated substantial artifact history, finish with:

```text
/meta-optimize "research-pipeline"
```

Use this only to generate a maintenance report and candidate patches for the harness. Do **not** auto-apply any patch from inside `research-pipeline`.

Recommended trigger points:

- after one full end-to-end project
- after repeated `auto-review-loop` stalls
- after a long `deep-innovation-loop` plateau
- after paper or rebuttal workflows reveal recurring harness friction

## Key Rules

- **Keep `CODEX.md` current.** Stage changes, active tasks, and next actions belong in `## Pipeline Status`.
- **Research Wiki is mainline memory, not decoration.** If enabled, let `/research-lit`, `/idea-creator`, and `/result-to-claim` update it continuously.
- **Deep innovation is now a mainline stage.** The default `auto` mode should decide whether to enter it; it is no longer purely an out-of-band optional extra.
- **Meta Optimize is maintenance, not research execution.** Use it after evidence accumulates; never let it block the research deliverables.
- **Fail gracefully.** If a stage cannot complete, write the blocker, preserve the artifacts, and propose the next-best continuation path.

## Typical Timeline

| Stage | Duration | Can sleep? |
|-------|----------|------------|
| 0. Memory setup | 1-5 min | Yes |
| 1. Idea discovery | 30-60 min | Yes |
| 2. Implementation | 15-60 min | Yes |
| 3. Initial deployment | 5 min + experiment time | Yes |
| 4. Deep innovation / review polish | 1 hour to overnight | Yes |
| 5. Final summary | 5-15 min | Yes |

**Sweet spot**: run Stages 0-3 in the evening, let Stage 4 evolve overnight, and wake up to a stabilized method plus a review-ready project state.
