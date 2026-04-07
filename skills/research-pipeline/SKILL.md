---
name: research-pipeline
description: "Full research pipeline: Workflow 1 (idea discovery) → implementation → Workflow 2 (auto review loop). Goes from a broad research direction all the way to a submission-ready paper. Use when user says \"全流程\", \"full pipeline\", \"从找idea到投稿\", \"end-to-end research\", or wants the complete autonomous research lifecycle."
argument-hint: [research-direction]
allowed-tools: Bash(*), Read, Write, Edit, Grep, Glob, WebSearch, WebFetch, Agent, Skill, Bash(codex*), Skill(codex:rescue), Skill(codex:adversarial-review)
---

# Full Research Pipeline: Idea → Experiments → Submission

End-to-end autonomous research workflow for: **$ARGUMENTS**

## Constants

- **AUTO_PROCEED = true** — When `true`, Gate 1 auto-selects the top-ranked idea (highest pilot signal + novelty confirmed) and continues to implementation. When `false`, always waits for explicit user confirmation before proceeding.
- **ARXIV_DOWNLOAD = false** — When `true`, `/research-lit` downloads the top relevant arXiv PDFs during literature survey. When `false` (default), only fetches metadata via arXiv API. Passed through to `/idea-discovery` → `/research-lit`.
- **HUMAN_CHECKPOINT = false** — When `true`, the auto-review loops (Stage 4) pause after each round's review to let you see the score and provide custom modification instructions before fixes are implemented. When `false` (default), loops run fully autonomously. Passed through to `/auto-review-loop`.
- **DEEP_INNOVATION = false** — When `true`, Stage 4 uses `/deep-innovation-loop` (40+ rounds of deep research-innovation cycles: diagnose root cause → research literature → design innovative variants → implement → evaluate → reflect → evolve) instead of the standard `/auto-review-loop` (4 rounds of review-fix). Use this for projects that require genuine methodological innovation, not just iterative polishing. Passed through to Stage 4.

> 💡 Override via argument, e.g., `/research-pipeline "topic" — AUTO_PROCEED: false, human checkpoint: true`.

## Full Autonomy Principle

This pipeline is designed to run **fully autonomously without human intervention**. At every decision point:

1. **Never block waiting for user input** — make the best decision based on available data, document the reasoning, and continue.
2. **Auto-select at forks** — when multiple options exist (ideas, variants, fix strategies), apply quantitative criteria to select the best one. Log the decision and alternatives.
3. **Auto-recover from failures** — when experiments fail, web searches hang, or reviews are harsh, diagnose the issue, apply the best fix, and continue. Exhaust at least 2 approaches before flagging as unresolvable.
4. **Auto-infer missing context** — when required files are absent (RESEARCH_BRIEF.md, EXPERIMENT_PLAN.md), infer the needed information from whatever IS available (CLAUDE.md, existing code, prior outputs).
5. **Document all autonomous decisions** — every auto-decision is logged with reasoning so the user can review after the fact. Format: `[AUTO-DECISION] Chose X over Y because Z`.

All downstream skills inherit this principle. No sub-skill should stop the pipeline to ask the user a question unless there is genuinely zero context to make any decision.

## Overview

This skill chains the entire research lifecycle into a single pipeline:

```
/idea-discovery → implement → /run-experiment → /auto-review-loop → submission-ready
├── Workflow 1 ──┤            ├────────── Workflow 2 ──────────────┤
```

It orchestrates two major workflows plus the implementation bridge between them.

## Pipeline

### Stage 1: Idea Discovery (Workflow 1)

If `RESEARCH_BRIEF.md` exists in the project root, it will be automatically loaded as detailed context (replaces one-line prompt). See `templates/RESEARCH_BRIEF_TEMPLATE.md`.

Invoke the idea discovery pipeline:

```
/idea-discovery "$ARGUMENTS"
```

This internally runs: `/research-lit` → `/idea-creator` → `/novelty-check` → `/research-review`

**Output:** `IDEA_REPORT.md` with ranked, validated, pilot-tested ideas.

**🚦 Gate 1 — Human Checkpoint:**

After `IDEA_REPORT.md` is generated, **pause and present the top ideas to the user**:

```
📋 Idea Discovery complete. Top ideas:

1. [Idea 1 title] — Pilot: POSITIVE (+X%), Novelty: CONFIRMED
2. [Idea 2 title] — Pilot: WEAK POSITIVE (+Y%), Novelty: CONFIRMED
3. [Idea 3 title] — Pilot: NEGATIVE, eliminated

Recommended: Idea 1. Shall I proceed with implementation?
```

**If AUTO_PROCEED=false:** Wait for user confirmation before continuing. The user may:
- **Approve an idea** → proceed to Stage 2.
- **Pick a different idea** → proceed with their choice.
- **Request changes** (e.g., "combine Idea 1 and 3", "focus more on X") → update the idea prompt with user feedback, re-run `/idea-discovery` with refined constraints, and present again.
- **Reject all ideas** → collect feedback on what's missing, re-run Stage 1 with adjusted research direction. Repeat until the user commits to an idea.
- **Stop here** → save current state to `IDEA_REPORT.md` for future reference.

**If AUTO_PROCEED=true:** Present the top ideas, wait 10 seconds for user input. If no response, auto-select the #1 ranked idea (highest pilot signal + novelty confirmed) and proceed to Stage 2. Log: `"AUTO_PROCEED: selected Idea 1 — [title]"`.

> ⚠️ **This gate waits for user confirmation when AUTO_PROCEED=false.** When `true`, it auto-selects the top idea after presenting results. The rest of the pipeline (Stages 2-4) is expensive (GPU time + multiple review rounds), so set `AUTO_PROCEED=false` if you want to manually choose which idea to pursue.

### Stage 2: Implementation

Once the user confirms which idea to pursue:

1. **Read the idea details** from `IDEA_REPORT.md` (hypothesis, experimental design, pilot code)

2. **Implement the full experiment**:
   - Extend pilot code to full scale (multi-seed, full dataset, proper baselines)
   - Add proper evaluation metrics and logging (wandb if configured)
   - Write clean, reproducible experiment scripts
   - Follow existing codebase conventions

3. **Code review**: Before deploying, do a self-review:
   - Are all hyperparameters configurable via argparse?
   - Is the random seed fixed and controllable?
   - Are results saved to JSON/CSV for later analysis?
   - Is there proper logging for debugging?

### Stage 3: Deploy Experiments (Workflow 2 — Part 1)

Deploy the full-scale experiments:

```
/run-experiment [experiment command]
```

**What this does:**
- Check GPU availability on configured servers
- Sync code to remote server
- Launch experiments in screen sessions with proper CUDA_VISIBLE_DEVICES
- Verify experiments started successfully

**Monitor progress:**

```
/monitor-experiment [server]
```

Wait for experiments to complete. Collect results.

### Stage 4: Method Evolution (Workflow 2 — Part 2)

Once initial results are in, start the improvement loop.

**If DEEP_INNOVATION = true** (for projects requiring genuine methodological innovation):

```
/deep-innovation-loop "$ARGUMENTS — [chosen idea title]" — baseline: [PRIMARY_BASELINE], venue: [VENUE]
```

**What this does (40+ rounds):**
1. GPT-5.4 xhigh diagnoses root causes (not just symptoms)
2. Claude Code researches literature for techniques addressing root causes
3. GPT-5.4 proposes innovative method variants with "1+1>2" fusion design
4. Claude Code implements the best variant, runs experiments
5. Both reflect on results, update technique library and evolution log
6. Repeat until score ≥ 8/10 or convergence plateau

**Output:** `innovation-logs/FINAL_METHOD.md`, `innovation-logs/EVOLUTION_LOG.md`, `innovation-logs/TECHNIQUE_LIBRARY.md`

After deep-innovation-loop completes, optionally run `/auto-review-loop` for 2-3 rounds of final paper-level polish.

**If DEEP_INNOVATION = false** (default — quick iterative polishing):

```
/auto-review-loop "$ARGUMENTS — [chosen idea title]"
```

**What this does (up to 4 rounds):**
1. GPT-5.4 xhigh reviews the work (score, weaknesses, minimum fixes)
2. Claude Code implements fixes (code changes, new experiments, reframing)
3. Deploy fixes, collect new results
4. Re-review → repeat until score ≥ 6/10 or 4 rounds reached

**Output:** `AUTO_REVIEW.md` with full review history and final assessment.

### Stage 5: Final Summary

After the auto-review loop completes, write a final status report:

```markdown
# Research Pipeline Report

**Direction**: $ARGUMENTS
**Chosen Idea**: [title]
**Date**: [start] → [end]
**Pipeline**: idea-discovery → implement → run-experiment → auto-review-loop

## Journey Summary
- Ideas generated: X → filtered to Y → piloted Z → chose 1
- Implementation: [brief description of what was built]
- Experiments: [number of GPU experiments, total compute time]
- Review rounds: N/4, final score: X/10
- [If DEEP_INNOVATION=true] Innovation rounds: N, method evolution: v0 → vN, techniques explored: M, final vs baseline improvement: [metrics]

## Final Status
- [ ] Ready for submission / [ ] Needs manual follow-up

## Remaining TODOs (if any)
- [items flagged by reviewer that weren't addressed]

## Files Changed
- [list of key files created/modified]
```

## Key Rules

- **Large file handling**: If the Write tool fails due to file size, immediately retry using Bash (`cat << 'EOF' > file`) to write in chunks. Do NOT ask the user for permission — just do it silently.

- **Human checkpoint after Stage 1 is controlled by AUTO_PROCEED.** When `false`, do not proceed without user confirmation. When `true`, auto-select the top idea after presenting results.
- **Stages 2-4 can run autonomously** once the user confirms the idea. This is the "sleep and wake up to results" part.
- **If Stage 4 ends at round 4 without positive assessment**, stop and report remaining issues. Do not loop forever.
- **Budget awareness**: Track total GPU-hours across the pipeline. Flag if approaching user-defined limits.
- **Documentation**: Every stage updates its own output file. The full history should be self-contained.
- **Fail gracefully**: If any stage fails (no good ideas, experiments crash, review loop stuck), report clearly and suggest alternatives rather than forcing forward.

## Typical Timeline

| Stage | Duration | Can sleep? |
|-------|----------|------------|
| 1. Idea Discovery | 30-60 min | Yes if AUTO_PROCEED=true |
| 2. Implementation | 15-60 min | Yes (autonomous after Gate 1) |
| 3. Deploy | 5 min + experiment time | Yes ✅ |
| 4. Auto Review | 1-4 hours (depends on experiments) | Yes ✅ |

**Sweet spot**: Run Stage 1-2 in the evening, launch Stage 3-4 before bed, wake up to a reviewed paper.
