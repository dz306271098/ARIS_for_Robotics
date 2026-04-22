---
name: "paper-writing"
description: "Workflow 3: Full paper writing pipeline. Orchestrates paper-plan → paper-figure → paper-write → paper-compile → auto-paper-improvement-loop to go from a narrative report to a polished, submission-ready PDF. Use when user says \\\"写论文全流程\\\", \\\"write paper pipeline\\\", \\\"从报告到PDF\\\", \\\"paper writing\\\", or wants the complete paper generation workflow."
allowed-tools: Bash(*), Read, Write, Edit, Grep, Glob, Agent, Skill
argument-hint: [narrative-report-path-or-topic]
---

> Override for Codex users who want **Claude Code**, not a second Codex agent, to act as the reviewer. Install this package **after** `skills/skills-codex/*`.

# Workflow 3: Paper Writing Pipeline

Orchestrate a complete paper writing workflow for: **$ARGUMENTS**

## Overview

This skill chains five sub-skills into a single automated pipeline:

```
/paper-plan → /paper-figure → /paper-write → /paper-compile → /auto-paper-improvement-loop
  (outline)     (plots)        (LaTeX)        (build PDF)       (review & polish ×2)
```

Each phase builds on the previous one's output. The final deliverable is a polished, reviewed `paper/` directory with LaTeX source and compiled PDF.

## Constants

- **VENUE = `ICLR`** — Target venue. Options: `ICLR`, `NeurIPS`, `ICML`, `CVPR`, `ACL`, `AAAI`, `ACM`, `IEEE_JOURNAL` (IEEE Transactions / Letters), `IEEE_CONF` (IEEE conferences). Affects style file, page limit, citation format.
- **MAX_IMPROVEMENT_ROUNDS = 2** — Number of review→fix→recompile rounds in the improvement loop.
- **REVIEWER_MODEL = `claude-review`** — Claude reviewer invoked through the local `claude-review` MCP bridge. Set `CLAUDE_REVIEW_MODEL` if you need a specific Claude model override.
- **AUTO_PROCEED = true** — Auto-continue between phases. Set `false` to pause and wait for user approval after each phase.
- **HUMAN_CHECKPOINT = false** — When `true`, the improvement loop (Phase 5) pauses after each round's review to let you see the score and provide custom modification instructions. When `false` (default), the loop runs fully autonomously. Passed through to `/auto-paper-improvement-loop`.
- **AUTONOMY_PROFILE = `CODEX.md -> ## Autonomy Profile`** — Project-level unattended-safe policy, including `paper_illustration: auto`.
- **AUTONOMY_STATE = `AUTONOMY_STATE.json`** — Cross-workflow state anchor updated before each phase transition and final completion/block.

> Override inline: `/paper-writing "NARRATIVE_REPORT.md" — venue: NeurIPS, human checkpoint: true`
> IEEE example: `/paper-writing "NARRATIVE_REPORT.md" — venue: IEEE_JOURNAL`

## Inputs

This pipeline accepts one of:

1. **`NARRATIVE_REPORT.md`** (best) — structured research narrative with claims, experiments, results, figures
2. **Research direction + experiment results** — the skill will help draft the narrative first
3. **Existing `PAPER_PLAN.md`** — skip Phase 1, start from Phase 2
4. **`CLAIMS_FROM_RESULTS.md`** — preferred claim-freeze artifact when the narrative needs to be refreshed before planning

The more detailed the input (especially figure descriptions and quantitative results), the better the output.

## Unattended Safe Mode

When `CODEX.md -> ## Autonomy Profile` sets `autonomy_mode: unattended_safe`:

- treat `paper_illustration: auto` as the default policy for architecture / pipeline figures
- update `AUTONOMY_STATE.json` before every phase transition and on any hard blocker
- if a required illustration has no existing artifact and no usable automatic backend, stop with `blocking_reason=missing_illustration_backend` instead of pretending the paper is complete
- if any section/outline/polish review used provisional local fallback, keep `review_replay_required=true` until the external reviewer replay succeeds
- keep `AUTO_PROCEED=true` and `HUMAN_CHECKPOINT=false` unless a hard safety boundary forces a stop

## Pipeline

### Phase 1: Paper Plan

Invoke `/paper-plan` to create the structural outline. If `NARRATIVE_REPORT.md` is missing but `CLAIMS_FROM_RESULTS.md` exists, first synthesize a narrative handoff from the approved claim scope, evidence package, and known limitations, then continue:

```
/paper-plan "$ARGUMENTS"
```

**What this does:**
- Parse NARRATIVE_REPORT.md for claims, evidence, and figure descriptions
- Build a **Claims-Evidence Matrix** — every claim maps to evidence, every experiment supports a claim
- Design section structure (5-8 sections depending on paper type)
- Plan figure/table placement with data sources
- Scaffold citation structure
- GPT-5.4 reviews the plan for completeness

**Output:** `PAPER_PLAN.md` with section plan, figure plan, citation scaffolding.

**Checkpoint:** Present the plan summary to the user.

```
📐 Paper plan complete:
- Title: [proposed title]
- Sections: [N] ([list])
- Figures: [N] auto-generated + [M] external-artifact / illustration-dependent
- Target: [VENUE], [PAGE_LIMIT] pages

Shall I proceed with figure generation?
```

- **User approves** (or AUTO_PROCEED=true) → proceed to Phase 2.
- **User requests changes** → adjust plan and re-present.

### Phase 2: Figure Generation

Invoke `/paper-figure` to generate data-driven plots and tables:

```
/paper-figure "PAPER_PLAN.md"
```

**What this does:**
- Read figure plan from PAPER_PLAN.md
- Generate matplotlib/seaborn plots from JSON/CSV data
- Generate LaTeX comparison tables
- Create `figures/latex_includes.tex` for easy insertion
- GPT-5.4 reviews figure quality and captions

**Output:** `figures/` directory with PDFs, generation scripts, and LaTeX snippets.

#### Phase 2b: AI Illustration Generation (when `illustration: true` or `paper_illustration: auto`)

**Skip this step entirely only if the paper plan contains no architecture / pipeline / conceptual figures that need illustration.** In unattended-safe mode, `CODEX.md -> ## Autonomy Profile -> paper_illustration: auto` should be treated as the default.

If the paper plan includes architecture diagrams, pipeline figures, or method illustrations, invoke `/paper-illustration`:

```
/paper-illustration "[method description from PAPER_PLAN.md or NARRATIVE_REPORT.md]"
```

**What this does:**
- Codex plans the layout → Gemini optimizes → Nano Banana Pro renders → Codex reviews (score ≥ 9)
- Output: `figures/ai_generated/*.png` — publication-quality method diagrams
- Requires a host-side Gemini/Paperbanana runtime. Do not call Gemini/Paperbanana directly from the Codex sandbox.

> **Without a usable illustration backend:** if the needed figure already exists in `figures/`, preserve it and continue. Otherwise create only provisional placeholders/spec artifacts, set `external_model_replay_required=true`, and keep `blocking_reason=missing_illustration_backend` or `external_illustration_pending` until the host runtime replay produces the real artifact.

**Checkpoint:** List generated vs external-artifact-dependent figures.

```
📊 Figures complete:
- Data plots (auto): [list]
- AI illustrations (auto): [list, if illustration: true]
- External artifacts (must already exist or block unattended mode): [list]
- LaTeX snippets: figures/latex_includes.tex

[If external artifacts are missing in unattended mode]: Stop and record `blocking_reason=missing_illustration_backend` or the missing asset path before proceeding.
[If all auto]: Shall I proceed with LaTeX writing?
```

### Phase 3: LaTeX Writing

Invoke `/paper-write` to generate section-by-section LaTeX:

```
/paper-write "PAPER_PLAN.md"
```

**What this does:**
- Write each section following the plan, with proper LaTeX formatting
- Insert figure/table references from `figures/latex_includes.tex`
- Build `references.bib` from citation scaffolding
- Clean stale files from previous section structures
- Automated bib cleaning (remove uncited entries)
- De-AI polish (remove "delve", "pivotal", "landscape"...)
- GPT-5.4 reviews each section for quality

**Output:** `paper/` directory with `main.tex`, `sections/*.tex`, `references.bib`, `math_commands.tex`.

**Checkpoint:** Report section completion.

```
✍️ LaTeX writing complete:
- Sections: [N] written ([list])
- Citations: [N] unique keys in references.bib
- Stale files cleaned: [list, if any]

Shall I proceed with compilation?
```

### Phase 4: Compilation

Invoke `/paper-compile` to build the PDF:

```
/paper-compile "paper/"
```

**What this does:**
- `latexmk -pdf` with automatic multi-pass compilation
- Auto-fix common errors (missing packages, undefined refs, BibTeX syntax)
- Up to 3 compilation attempts
- Post-compilation checks: undefined refs, page count, font embedding
- Precise page verification via `pdftotext`
- Stale file detection

**Output:** `paper/main.pdf`

**Checkpoint:** Report compilation results.

```
🔨 Compilation complete:
- Status: SUCCESS
- Pages: [X] (main body) + [Y] (references) + [Z] (appendix)
- Within page limit: YES/NO
- Undefined references: 0
- Undefined citations: 0

Shall I proceed with the improvement loop?
```

### Phase 5: Auto Improvement Loop

Invoke `/auto-paper-improvement-loop` to polish the paper:

```
/auto-paper-improvement-loop "paper/"
```

**What this does (2 rounds):**

**Round 1:** Claude review reviews the full paper → identifies CRITICAL/MAJOR/MINOR issues → Codex implements fixes → recompile → save `main_round1.pdf`

**Round 2:** Claude review re-reviews with conversation context → identifies remaining issues → Codex implements fixes → recompile → save `main_round2.pdf`

**Typical improvements:**
- Fix assumption-model mismatches
- Soften overclaims to match evidence
- Add missing interpretations and notation
- Strengthen limitations section
- Add theory-aligned experiments if needed

**Output:** Three PDFs for comparison + `PAPER_IMPROVEMENT_LOG.md`.

**Format check** (included in improvement loop Step 8): After final recompilation, auto-detect and fix overfull hboxes (content exceeding margins), verify page count vs venue limit, and ensure compact formatting. Any overfull > 10pt is fixed before generating the final PDF.

### Phase 6: Final Report

```markdown
# Paper Writing Pipeline Report

**Input**: [NARRATIVE_REPORT.md or topic]
**Venue**: [ICLR/NeurIPS/ICML]
**Date**: [today]

## Pipeline Summary

| Phase | Status | Output |
|-------|--------|--------|
| 1. Paper Plan | ✅ | PAPER_PLAN.md |
| 2. Figures | ✅ | figures/ ([N] auto + [M] external-artifact / illustration-dependent) |
| 3. LaTeX Writing | ✅ | paper/sections/*.tex ([N] sections, [M] citations) |
| 4. Compilation | ✅ | paper/main.pdf ([X] pages) |
| 5. Improvement | ✅ | [score0]/10 → [score2]/10 |

## Improvement Scores
| Round | Score | Key Changes |
|-------|-------|-------------|
| Round 0 | X/10 | Baseline |
| Round 1 | Y/10 | [summary] |
| Round 2 | Z/10 | [summary] |

## Deliverables
- paper/main.pdf — Final polished paper
- paper/main_round0_original.pdf — Before improvement
- paper/main_round1.pdf — After round 1
- paper/main_round2.pdf — After round 2
- paper/PAPER_IMPROVEMENT_LOG.md — Full review log

## Remaining Issues (if any)
- [items from final review that weren't addressed]

## Next Steps
- [ ] Visual inspection of PDF
- [ ] Resolve any remaining external-artifact or illustration backend blockers
- [ ] Submit to [venue] via OpenReview / CMT / HotCRP
```

## Key Rules

- **Large file handling**: If the Write tool fails due to file size, immediately retry using Bash (`cat << 'EOF' > file`) to write in chunks. Do NOT ask the user for permission — just do it silently.

- **Don't skip phases.** Each phase builds on the previous one — skipping leads to errors.
- **Checkpoint between phases** when AUTO_PROCEED=false. Present results and wait for approval.
- **Manual figures first.** If the paper needs architecture diagrams or qualitative results, the user must provide them before Phase 3.
- **Compilation must succeed** before entering the improvement loop. Fix all errors first.
- **Preserve all PDFs.** The user needs round0/round1/round2 for comparison.
- **Document everything.** The pipeline report should be self-contained.
- **Respect page limits.** If the paper exceeds the venue limit, suggest specific cuts before the improvement loop.

## Composing with Other Workflows

```
/idea-discovery "direction"         ← Workflow 1: find ideas
implement                           ← write code
/run-experiment                     ← deploy experiments
/auto-review-loop "paper topic"     ← Workflow 2: iterate research
/paper-writing "NARRATIVE_REPORT.md"  ← Workflow 3: you are here
                                         submit! 🎉

Or use /research-pipeline for the Workflow 1+2 end-to-end flow,
then /paper-writing for the final writing step.
```

## Typical Timeline

| Phase | Duration | Can sleep? |
|-------|----------|------------|
| 1. Paper Plan | 5-10 min | No |
| 2. Figures | 5-15 min | No |
| 3. LaTeX Writing | 15-30 min | Yes ✅ |
| 4. Compilation | 2-5 min | No |
| 5. Improvement | 15-30 min | Yes ✅ |

**Total: ~45-90 min** for a full paper from narrative report to polished PDF.
