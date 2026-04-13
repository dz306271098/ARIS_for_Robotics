---
name: meta-optimize
description: "Analyze ARIS workflow evidence and propose optimizations to SKILL.md files, reviewer prompts, and workflow defaults. Use when user says \"优化技能\", \"meta optimize\", \"improve skills\", \"分析使用记录\", or wants to improve ARIS's own harness based on real project traces."
argument-hint: [target-skill-or-all]
allowed-tools: Bash(*), Read, Write, Edit, Grep, Glob, Agent, Bash(codex*), Skill(codex:rescue), Skill(codex:adversarial-review)
---

# Meta-Optimize: Outer-Loop Harness Optimization for ARIS

Analyze accumulated project evidence and propose harness improvements for: **$ARGUMENTS**

## Context

ARIS is a research harness. This skill optimizes the harness itself:

- skill prompts
- default parameters
- convergence rules
- workflow ordering
- artifact contracts

It does **not** optimize the research artifact directly. Papers, code, and experiments stay in the normal research workflow; `meta-optimize` improves the system that produced them.

## Codex-First Mainline Note

In the current Codex executor + Claude reviewer mainline, `meta-optimize` should be treated as a **maintenance loop** that runs after evidence has accumulated.

It supports two evidence modes:

| Mode | When to use | Required input |
|------|-------------|----------------|
| **Artifact-first** | Default for Codex mainline | `AUTO_REVIEW.md`, `innovation-logs/`, `refine-logs/`, `findings.md`, `paper/`, `rebuttal/`, `CODEX.md` |
| **Event-log enhanced** | Optional, when you also collect hook logs | `.aris/meta/events.jsonl` plus the artifacts above |

Hook logs are helpful but no longer mandatory. If `.aris/meta/events.jsonl` does not exist, analyze the project artifacts instead of erroring out.

## Recommended Workflow Embedding

Use `meta-optimize` at milestone boundaries, not in the middle of a fragile experiment run:

1. After one full `/research-pipeline` pass:
   ```text
   /meta-optimize "research-pipeline"
   ```
2. After repeated review stalls:
   ```text
   /meta-optimize "auto-review-loop"
   ```
3. After a long innovation plateau:
   ```text
   /meta-optimize "deep-innovation-loop"
   ```
4. After paper-writing or rebuttal friction:
   ```text
   /meta-optimize "paper-writing"
   /meta-optimize "rebuttal"
   ```
5. When you want a cross-project maintenance sweep:
   ```text
   /meta-optimize all
   ```

Never auto-apply harness patches from inside a main research workflow. Generate a report first, review it, then explicitly apply a selected change.

## Optional Logging Enhancement

If you want passive event logs in addition to artifact analysis, merge:

```text
templates/claude-hooks/meta_logging.json
```

into any Claude Code sessions you still run for auxiliary work. This writes:

- project log: `.aris/meta/events.jsonl`
- global log: `~/.aris/meta/events.jsonl`

and uses:

- `tools/meta_opt/log_event.sh`
- `tools/meta_opt/check_ready.sh`

The hook path is optional enhancement, not a hard prerequisite for the Codex mainline.

## Workflow

### Step 0: Determine Available Evidence

Check for evidence in this order:

1. `.aris/meta/events.jsonl`
2. `AUTO_REVIEW.md`, `REVIEW_STATE.json`
3. `innovation-logs/INNOVATION_STATE.json`, `innovation-logs/EVOLUTION_LOG.md`, `innovation-logs/score-history.csv`
4. `refine-logs/EXPERIMENT_PLAN.md`, `refine-logs/EXPERIMENT_TRACKER.md`, `EXPERIMENT_LOG.md`, `findings.md`
5. `paper/`, `PAPER_IMPROVEMENT_LOG.md`, `rebuttal/`
6. `CODEX.md` for current defaults, recurring overrides, and project-level constraints

If **none** of these are present, stop and report:

```text
Insufficient evidence for meta-optimize. Finish at least one major workflow stage first.
```

### Step 1: Build an Evidence Summary

#### If event logs exist

Analyze:

- most-invoked skills
- repeated parameter overrides
- repeated tool failures
- sessions between optimizations
- manual interruptions and recurring user corrections

#### Always analyze artifacts

Look for:

- repeated `auto-review-loop` criticisms across rounds or projects
- repeated `deep-innovation-loop` plateaus, regressions, or blacklisted patterns
- repeated experiment failures or rescue patterns in `findings.md`
- repeated paper-writing or rebuttal issues
- places where `CODEX.md` repeatedly forces the same manual workaround because a skill default is poor

Present a compact table of recurring friction:

```markdown
| Signal | Evidence | Likely harness problem |
|--------|----------|------------------------|
| Auto-review keeps asking for the same ablation | AUTO_REVIEW.md rounds 2-4 | experiment-plan under-specifies must-run ablations |
| Deep loop plateaus after 3 rounds | innovation-logs/score-history.csv | diagnosis step too shallow or blacklist not enforced strongly |
| Paper compile failures repeat | PAPER_IMPROVEMENT_LOG.md | paper-write emits brittle LaTeX patterns |
```

### Step 2: Identify Optimization Targets

Rank opportunities by expected impact and confidence:

```markdown
## Optimization Opportunities

| # | Target | Evidence | Proposed Change | Confidence |
|---|--------|----------|-----------------|------------|
| 1 | research-pipeline default stage ordering | deep innovation was manually inserted in multiple projects | make innovation gate part of mainline | high |
| 2 | idea-creator wiki integration | repeated re-discovery of failed ideas | load query_pack before ideation and write killed ideas back | high |
| 3 | paper-writing default venue checks | repeated page-limit fixes | add earlier page-budget validation | medium |
```

If `$ARGUMENTS` names a specific skill, focus only on that surface.

### Step 3: Generate Minimal Patch Proposals

For each target, write a small diff and tie it to evidence. One patch per idea.

Rules:

- minimal changes only
- cite evidence explicitly
- do not auto-change bridge infra
- do not rewrite large skills without a traceable reason

### Step 4: Cross-Model Review

Before recommending a patch, run a cross-model review using the reviewer path available in the current environment. The reviewer should answer:

1. Does the evidence support the proposed change?
2. Could the change hurt other workflows?
3. Is this the minimal safe fix?
4. Should the patch be applied now, later, or never?

If no external reviewer path is available, do a local critical review and mark it as such.

### Step 5: Present the Report

Output:

```markdown
# ARIS Meta-Optimization Report

**Target**: [skill or all]
**Evidence mode**: artifact-first | event-log enhanced

## Proposed Changes
- [change 1]
- [change 2]

## Deferred Changes
- [needs more evidence]

## Recommended Next Actions
- [ ] Apply change 1
- [ ] Collect more evidence for change 2
- [ ] Re-run meta-optimize after next milestone
```

### Step 6: Apply Only on Explicit Command

If the user runs:

```text
/meta-optimize apply 1
/meta-optimize apply all
```

then:

1. back up the touched skill files to `.aris/meta/backups/`
2. apply the patch
3. append a record to `.aris/meta/optimizations.jsonl`
4. recommend validating the changed workflow on the next project

Never auto-apply from a read-only analysis run.

## Triggering

`meta-optimize` is not part of the default research execution loop. It is a maintenance layer triggered by:

- explicit user request
- end-of-milestone review
- optional SessionEnd reminder from `tools/meta_opt/check_ready.sh` when hook logs are enabled

The SessionEnd reminder is advisory only.

## Key Rules

- **Artifact evidence is first-class.** Lack of hook logs is not a reason to abort.
- **Log-driven, not vibe-driven.** Every patch must tie back to concrete traces or artifacts.
- **Maintenance is downstream of research, not upstream.** Do not stall the active project to refactor the harness mid-flight.
- **Never auto-apply.** Optimization proposals must be reviewed before they mutate the harness.
- **Optimize for future runs.** The purpose is to reduce repeated friction in the next project, not to churn the current one for marginal prompt cosmetics.
