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
- **RESEARCH_INTELLIGENCE_PROFILE = `CODEX.md -> ## Research Intelligence Profile`** — Project-level defaults for topic routing, innovation intensity, literature depth, portfolio size, and shadow-route retention.
- **IDEA_PORTFOLIO_SIZE = 3** — Preserve at least `safe`, `bold`, and `contrarian` routes until novelty/review/cheap pilot pressure kills them.
- **EXECUTION_PROFILE = `CODEX.md -> ## Execution Profile`** — Project-level execution route selector. Defaults to `python_ml`; `cpp_algorithm` now covers both `cpu_benchmark` and `cpu_cuda_mixed`, while `robotics_slam` switches the mainline to an offline robotics / SLAM path without creating a second workflow tree.
- **AUTONOMY_PROFILE = `CODEX.md -> ## Autonomy Profile`** — Project-level unattended-safe policy. When it sets `autonomy_mode: unattended_safe`, this skill becomes the host-orchestrated core-mainline entrypoint.
- **AUTONOMY_STATE = `AUTONOMY_STATE.json`** — Cross-workflow state anchor updated alongside workflow-native recovery files.

> 💡 Override via argument, e.g. `/research-pipeline "topic" — AUTO_PROCEED: false, DEEP_INNOVATION: true, RESEARCH_WIKI: true`.

## Full Autonomy Principle

This pipeline is designed to run with minimal supervision:

1. **Never block without reason** — if enough evidence exists to make a defensible choice, make it and log the reasoning.
2. **Auto-select at forks** — idea choice, implementation path, and innovation/polish routing should be based on evidence, not hesitation.
3. **Auto-recover** — when experiments fail, diagnose, fix, and retry before declaring a hard blocker.
4. **Use durable memory when available** — `CODEX.md`, `research-wiki/`, `refine-logs/`, `AUTO_REVIEW.md`, and `innovation-logs/` are part of the working state, not optional afterthoughts.
5. **Log autonomous decisions** — write `[AUTO-DECISION]` notes into the relevant artifact whenever the pipeline chooses a path on the user's behalf.

## Unattended Safe Mode

When `CODEX.md -> ## Autonomy Profile` sets `autonomy_mode: unattended_safe`:

- run `bash scripts/check_unattended_mainline.sh /path/to/project` before dispatching the workflow
- treat `allow_auto_cloud: false` and `allow_auto_real_robot: false` as hard safety boundaries
- update `AUTONOMY_STATE.json` at every stage boundary, blocker, and final completion via `python3 tools/update_autonomy_state.py`
- keep `AUTO_PROCEED=true` and `HUMAN_CHECKPOINT=false` unless the autonomy profile explicitly forces a stop
- track `portfolio_stage`, `active_route`, and `shadow_routes` whenever the pipeline is still carrying multiple candidate directions
- prefer resumable continuation from `AUTONOMY_STATE.json` + workflow-native state files over ad-hoc restarts

## Overview

The mainline path is now:

```text
/idea-discovery -> /experiment-bridge -> /monitor-experiment + /training-check -> /result-to-claim -> /deep-innovation-loop? -> /auto-review-loop -> /result-to-claim -> narrative handoff -> /paper-writing -> paper-ready PDF
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

### Stage 0.5: Topic Routing and Research Intelligence

Before ideation, read both `CODEX.md -> ## Research Intelligence Profile` and `CODEX.md -> ## Execution Profile` if they exist. Use them to decide:

- whether the project runs in `high_innovation` or `quality_stability` mode
- how many routes to preserve before convergence
- whether to keep a shadow route alive after Gate 1
- whether the topic should auto-route to a domain-aware literature/idea path
- whether downstream execution should be treated as `python_ml`, `cpp_algorithm`, `robotics_slam`, or a hybrid path

Default topic routing policy:

- robotics / embodied AI / manipulation / navigation / locomotion / VO / VIO / LiDAR SLAM / 3D perception -> `/idea-discovery-robot`
- communications / wireless / networking / NTN / MAC/PHY / transport -> `comm-lit-review` for literature grounding, then continue the standard idea pipeline
- everything else -> standard `/idea-discovery`

Execution-route defaults after ideation:

- `project_stack: python_ml` -> keep the existing training / W&B-friendly execution semantics
- `project_stack: cpp_algorithm` / `runtime_profile: cpu_benchmark` -> carry benchmark suite, toolchain, correctness-oracle, and scaling constraints forward into `/experiment-bridge`, `/run-experiment`, `/monitor-experiment`, and `/result-to-claim`
- `project_stack: cpp_algorithm` / `runtime_profile: cpu_cuda_mixed` -> also carry CUDA toolkit, `nvcc`, profiler backend, kernel/transfer metrics, and CPU-GPU overlap constraints forward into `/experiment-bridge`, `/run-experiment`, `/monitor-experiment`, and `/result-to-claim`
- `project_stack: robotics_slam` / `runtime_profile: slam_offline` -> carry dataset / rosbag / simulator constraints, trajectory/perception metrics, ground-truth assumptions, and optional ROS2 adapter requirements forward into `/experiment-bridge`, `/run-experiment`, `/monitor-experiment`, and `/result-to-claim`

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
- `IDEA_PORTFOLIO.md`
- `refine-logs/ROUTE_PORTFOLIO.md`
- `refine-logs/FINAL_PROPOSAL.md`
- `refine-logs/EXPERIMENT_PLAN.md`
- `refine-logs/PLAN_DECISIONS.md`
- `refine-logs/EXPERIMENT_TRACKER.md`

**Gate 1**

After `IDEA_REPORT.md` is ready:

- If `AUTO_PROCEED = false`, wait for explicit idea selection.
- If `AUTO_PROCEED = true`, auto-select the best evidence-backed **mainline** idea and keep one `shadow route` alive unless the portfolio has already collapsed to one credible route.
- Record both the active route and the surviving shadow route in `AUTONOMY_STATE.json` while the branch is still alive.

If `research-wiki/` is enabled, Stage 1 should already:

- ingest relevant papers via `/research-lit`
- read `query_pack.md` before ideation
- write recommended and killed ideas back into `research-wiki/ideas/`

### Stage 2: Experiment Bridge

Once the idea is chosen, execute the implementation and launch path through:

```text
/experiment-bridge "$ARGUMENTS — [chosen idea title]"
```

This stage owns:
- full experiment implementation from `IDEA_REPORT.md` + `refine-logs/`
- module tests and workflow smoke tests before deployment
- initial deployment through `/run-experiment`
- first monitoring loop through `/monitor-experiment` and `/training-check` when the execution profile is training-oriented
- compiled-project setup when `project_stack: cpp_algorithm`: CMake targets, CTest, benchmark binaries, parsers, reproducibility commands, and when needed CUDA toolchain / profiling hooks
- robotics/SLAM setup when `project_stack: robotics_slam`: offline replay / evaluation commands, trajectory and perception summaries, dataset-or-rosbag matrices, and optional `cmake_ros2` adapter steps
- sidecar escalation to `/dse-loop` or `/system-profile` when the benchmark plan calls for sweeps or hotspot diagnosis

In unattended-safe mode, Stage 2 should update `AUTONOMY_STATE.json` before implementation, after the test gate, after launch, and on any deployment blocker.

### Stage 3: First Claim Gate

After the first decisive evidence package lands, run:

```text
/result-to-claim "$ARGUMENTS — [chosen idea title]"
```

This gate decides whether the current evidence supports:
- immediate continuation with the approved claim scope
- supplementary experiments
- a `deep-innovation-loop` pivot
- abandonment of the current thesis

Do not enter narrative polishing or paper writing before a `result-to-claim` verdict records the strongest defensible claim scope.

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

After the polish loop, run `/result-to-claim` again to freeze the strongest defensible post-innovation claim set.

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

After the polish loop, run `/result-to-claim` again to freeze the final approved claim boundaries before paper planning.

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

### Stage 5: Narrative Handoff and Paper Writing

Once the final `result-to-claim` gate says the claim set is defensible enough for papering:

1. Refresh or create `NARRATIVE_REPORT.md` from:
   - `CLAIMS_FROM_RESULTS.md`
   - `findings.md`
   - `AUTO_REVIEW.md`
   - `innovation-logs/` when deep innovation ran
2. Record any provisional review fallback in `AUTONOMY_STATE.json` via `review_mode`, `review_replay_required`, and `recovery_step`
3. Invoke:

```text
/paper-writing "NARRATIVE_REPORT.md"
```

Do not mark the workflow complete while `review_replay_required = true` for claim freeze or final paper polish.

### Stage 6: Final Summary

After the paper-writing stage, write a final status report:

```markdown
# Research Pipeline Report

**Direction**: $ARGUMENTS
**Chosen Idea**: [title]
**Date**: [start] -> [end]
**Pipeline**: idea-discovery -> experiment-bridge -> result-to-claim -> deep-innovation? -> auto-review-loop -> result-to-claim -> paper-writing

## Journey Summary
- Ideas generated: X -> filtered to Y -> piloted Z -> chose 1
- Implementation: [what was built]
- Experiments: [number of runs, total compute time]
- First claim gate: [yes / partial / no], approved scope: [summary]
- Deep innovation: [skipped / auto-entered / forced], rounds: [N]
- Final review rounds: [N], final score: [X/10]
- Final claim freeze: [yes / partial / no], approved scope: [summary]
- Paper writing: [completed / blocked], PDF: [path]

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
