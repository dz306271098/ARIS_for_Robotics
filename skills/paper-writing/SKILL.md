---
name: paper-writing
description: "Workflow 3: Full paper writing pipeline. Orchestrates paper-plan → paper-figure → paper-write → paper-compile → auto-paper-improvement-loop to go from a narrative report to a polished, submission-ready PDF. Use when user says \"写论文全流程\", \"write paper pipeline\", \"从报告到PDF\", \"paper writing\", or wants the complete paper generation workflow."
argument-hint: [narrative-report-path-or-topic]
allowed-tools: Bash(*), Read, Write, Edit, Grep, Glob, Agent, Skill, Bash(codex*), Skill(codex:rescue), Skill(codex:adversarial-review)
---

# Workflow 3: Paper Writing Pipeline

Orchestrate a complete paper writing workflow for: **$ARGUMENTS**

## Overview

This skill chains five sub-skills into a single automated pipeline:

```
/paper-plan → /paper-figure → /paper-write → /paper-compile → /auto-paper-improvement-loop
  (outline)     (plots)        (LaTeX)        (build PDF)       (review & polish ×2)
```

Each phase builds on the previous one's output. The final deliverable is a polished, reviewed `paper/` directory with LaTeX source and compiled PDF.

In this hybrid pack, the pipeline itself is unchanged, but `paper-plan` and `paper-write` use Orchestra-adapted shared references for stronger story framing and prose guidance.

## Constants

- **VENUE = `ICLR`** — Target venue. Options: `ICLR`, `NeurIPS`, `ICML`, `CVPR`, `ACL`, `AAAI`, `ACM`, `IEEE_JOURNAL` (IEEE Transactions / Letters), `IEEE_CONF` (IEEE conferences). Affects style file, page limit, citation format.
- **MAX_IMPROVEMENT_ROUNDS = 2** — Number of review→fix→recompile rounds in the improvement loop.
- **REVIEWER_MODEL = `gpt-5.4`** — Model used via Codex CLI for plan review, figure review, writing review, and improvement loop.
- **AUTO_PROCEED = true** — Auto-continue between phases. Set `false` to pause and wait for user approval after each phase.
- **HUMAN_CHECKPOINT = false** — When `true`, the improvement loop (Phase 5) pauses after each round's review to let you see the score and provide custom modification instructions. When `false` (default), the loop runs fully autonomously. Passed through to `/auto-paper-improvement-loop`.
- **EFFORT = balanced** — Work intensity level. Options: `lite`, `balanced`, `max`, `beast`. Passed to all sub-skills. See `../shared-references/effort-contract.md`.

> Override inline: `/paper-writing "NARRATIVE_REPORT.md" — venue: NeurIPS, human checkpoint: true`
> IEEE example: `/paper-writing "NARRATIVE_REPORT.md" — venue: IEEE_JOURNAL`

## Inputs

This pipeline accepts one of:

1. **`NARRATIVE_REPORT.md`** (best) — structured research narrative with claims, experiments, results, figures
2. **Research direction + experiment results** — the skill will help draft the narrative first
3. **Existing `PAPER_PLAN.md`** — skip Phase 1, start from Phase 2

The more detailed the input (especially figure descriptions and quantitative results), the better the output.

## Pipeline

### Phase 0: Assurance Resolution (MANDATORY first step)

Resolve the **assurance level** before any other work. See `../shared-references/assurance-contract.md` for the axis specification.

```bash
# Parse --assurance from arguments; default-map from effort if not given
ASSURANCE="${ASSURANCE:-}"
if [ -z "$ASSURANCE" ]; then
    case "$EFFORT" in
        lite|balanced|"") ASSURANCE="draft" ;;
        max|beast)        ASSURANCE="submission" ;;
        *)                ASSURANCE="draft" ;;
    esac
fi
mkdir -p paper/.aris
echo "$ASSURANCE" > paper/.aris/assurance.txt
echo "📋 Assurance level: $ASSURANCE"
```

**Default mapping** (per `assurance-contract.md`):

| `effort` | implied `assurance` |
|----------|---------------------|
| `lite` | `draft` |
| `balanced` (default) | `draft` |
| `max` | `submission` |
| `beast` | `submission` |

Override independently: `/paper-writing ... — effort: balanced, assurance: submission` is legal and means "normal depth, every audit must emit a verdict before finalization."

**What this enables**:
- `submission` level → Phase 6 invokes `tools/verify_paper_audits.sh`; non-zero exit blocks Final Report.
- `draft` level → audits still run where their detector matches; verifier runs in advisory mode.
- The mode is persisted to `paper/.aris/assurance.txt` — machine-readable so the verifier and subsequent phases all agree.

**Why this phase exists**: historically `effort: beast` could silently skip mandatory audits because each audit's content detector could return negative and no artifact was written. Phase 0 separates "what depth of work to do" (`effort`) from "how rigorously must audits emit verdicts" (`assurance`). Passing only `— effort: beast` automatically engages `assurance: submission` — matching intent.

---

### Phase 0.5: Research-Wiki Context Load (if `research-wiki/` exists)

**Skip entirely if `research-wiki/` does not exist.**

Before paper-plan reads NARRATIVE_REPORT.md, harvest context from the research wiki for richer Related Work / Limitations / Method-positioning sections:

1. **Read `research-wiki/query_pack.md`** — compressed landscape summary (principles + unresolved failures + paper clusters).
2. **Read `research-wiki/AUDIT_REPORT.md`** if exists, focusing on:
   - Analysis (c) Principle coverage — principles our method embodies; useful for Method section framing.
   - Analysis (d) Unresolved failure patterns — if our method addresses one, this is a first-class Related Work / motivation citation.
3. **Identify the principles our method embodies** (from `research-wiki/principles/` if populated from prior `/research-lit` runs).
4. **Identify the failure patterns our method resolves or avoids** (from `research-wiki/failures/`). These become:
   - Related Work positioning: "Prior work reports [failure X] for methods embodying [principle Y]. Our method avoids this by [mechanism]."
   - Limitations: acknowledge any failure patterns we did NOT address (honest scoping).
5. **Persist the harvest** to `NARRATIVE_REPORT.md` under a new `## Wiki-Sourced Positioning` section so `/paper-plan` reads it in Phase 1.

This step is additive — it enriches paper-plan's inputs but does not replace them. If the wiki is thin, the harvest is short; paper-plan proceeds normally on NARRATIVE_REPORT.md alone.

### Phase 1: Paper Plan

Invoke `/paper-plan` to create the structural outline:

```
/paper-plan "$ARGUMENTS"
```

**What this does:**
- Parse NARRATIVE_REPORT.md for claims, evidence, and figure descriptions (now including wiki-sourced positioning from Phase 0.5 if run)
- Build a **Claims-Evidence Matrix** — every claim maps to evidence, every experiment supports a claim
- Design section structure (5-8 sections depending on paper type)
- Plan figure/table placement with data sources
- Scaffold citation structure with wiki principle / failure citations where applicable
- GPT-5.4 reviews the plan for completeness

**Output:** `PAPER_PLAN.md` with section plan, figure plan, citation scaffolding.

**Checkpoint:** Present the plan summary to the user.

```
📐 Paper plan complete:
- Title: [proposed title]
- Sections: [N] ([list])
- Figures: [N] auto-generated + [M] manual
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

> **Scope:** Auto-generates ~60% of figures (data plots, comparison tables). Architecture diagrams, pipeline figures, and qualitative result grids must be created manually and placed in `figures/` before proceeding. See `/paper-figure` SKILL.md for details.

**Checkpoint:** List generated vs manual figures.

```
📊 Figures complete:
- Auto-generated: [list]
- Manual (need your input): [list]
- LaTeX snippets: figures/latex_includes.tex

[If manual figures needed]: Please add them to figures/ before I proceed.
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

### Phase 4.5: Proof Verification (theory papers only)

**Skip this phase if the paper contains no theorems, lemmas, or proofs.**

Check whether the compiled paper uses theorem environments:

```bash
THEOREM_ENVS=$(grep -rn '\\begin{theorem}\|\\begin{lemma}\|\\begin{proposition}\|\\begin{corollary}\|\\begin{proof}' paper/sections/ paper/main.tex 2>/dev/null || true)
```

If `THEOREM_ENVS` is non-empty, invoke the proof-checker skill:

```
/proof-checker "paper/"
```

**What this does:**
- Verify all proof steps (hypothesis discharge, interchange justification, etc.)
- Check for logic gaps, quantifier errors, missing domination conditions
- Attempt counterexamples on key lemmas
- Generate `PROOF_AUDIT.md` with issue list and severity ratings

**Blocking rule:**
- If `PROOF_AUDIT.md` contains **FATAL** or **CRITICAL** issues: fix them before proceeding to Phase 5.
- If only **MAJOR** or **MINOR** issues remain: proceed -- the improvement loop may address them.
- If no theorem environments found: skip this phase entirely.

### Phase 4.7: Paper Claim Audit (papers with experiments)

**Skip if no result files exist (e.g., survey/position papers with no experiments).**

Check whether machine-readable result files are present:

```bash
RAW_RESULT_FILES=$(find results outputs experiments figures -type f \
  \( -name '*.json' -o -name '*.jsonl' -o -name '*.csv' -o -name '*.tsv' -o -name '*.yaml' -o -name '*.yml' \) 2>/dev/null | head -200)
```

If `RAW_RESULT_FILES` is non-empty, invoke the paper-claim-audit skill:

```
/paper-claim-audit "paper/"
```

**What this does:**
- A fresh zero-context reviewer compares every number in the paper against raw result files
- Catches rounding inflation, best-seed cherry-pick, config mismatch, delta errors

**Blocking rule:**
- If `number_mismatch` count > 0: fix mismatched numbers before proceeding to Phase 5.
- If only warnings: proceed, but flag for manual verification.
- If no result files found: skip this phase entirely.

### Phase 5: Auto Improvement Loop

Invoke `/auto-paper-improvement-loop` to polish the paper:

```
/auto-paper-improvement-loop "paper/"
```

**What this does (2 rounds):**

**Round 1:** GPT-5.4 xhigh reviews the full paper → identifies CRITICAL/MAJOR/MINOR issues → Claude Code implements fixes → recompile → save `main_round1.pdf`

**Round 2:** GPT-5.4 xhigh re-reviews with conversation context → identifies remaining issues → Claude Code implements fixes → recompile → save `main_round2.pdf`

**Typical improvements:**
- Fix assumption-model mismatches
- Soften overclaims to match evidence
- Add missing interpretations and notation
- Strengthen limitations section
- Add theory-aligned experiments if needed

**Output:** Three PDFs for comparison + `PAPER_IMPROVEMENT_LOG.md`.

**Format check** (included in improvement loop Step 8): After final recompilation, auto-detect and fix overfull hboxes (content exceeding margins), verify page count vs venue limit, and ensure compact formatting. Any overfull > 10pt is fixed before generating the final PDF.

### Phase 5.5: Final Paper Claim Audit (MANDATORY)

> **Not a duplicate of Phase 4.7.** Phase 4.7 audits the paper BEFORE the improvement loop. This phase RE-AUDITS AFTER the improvement loop, because the loop may introduce new numeric claims (e.g., synthetic validation results), modify existing numbers (e.g., softening overclaims, rounding adjustments), or alter aggregation methods. Empirically: caught 2 real mismatches in April 2026 NeurIPS submission (width parameter drift and crossing-point tolerance change introduced during Round 2 fixes).

After `/auto-paper-improvement-loop` finishes, **rerun** `/paper-claim-audit` before the final report whenever the paper contains numeric claims and machine-readable raw result files exist. This is a mandatory submission gate.

**Detection script:**

```bash
# Detect numeric claims in paper source
NUMERIC_CLAIMS=$(rg -n -e '[0-9]+(\.[0-9]+)?\s*(%|\\%|±|\\pm|x|×)' \
  -e '(accuracy|BLEU|F1|AUC|mAP|top-1|top-5|error|loss|perplexity|speedup|improvement)' \
  paper/main.tex paper/sections 2>/dev/null || true)

# Detect raw result files
RAW_RESULT_FILES=$(find results outputs experiments figures -type f \
  \( -name '*.json' -o -name '*.jsonl' -o -name '*.csv' -o -name '*.tsv' -o -name '*.yaml' -o -name '*.yml' \) 2>/dev/null | head -200)

if [ -n "$NUMERIC_CLAIMS" ] && [ -n "$RAW_RESULT_FILES" ]; then
    # Both numeric claims and raw data exist -- audit is mandatory
    /paper-claim-audit "paper/"
    # If FAIL: fix mismatched numbers before the final report
elif [ -n "$NUMERIC_CLAIMS" ]; then
    # Paper has numeric claims but no raw evidence files found
    # BLOCK: stop and warn the user before declaring the paper complete
    echo "WARNING: Paper contains numeric claims but no raw result files were found."
    echo "Cannot verify claim accuracy. Add result files or remove unsupported claims."
fi
```

**Blocking rules:**
- If both detectors fire and `/paper-claim-audit` returns FAIL: fix mismatched numbers before generating the final report.
- If numeric claims exist but no raw result files are found: **stop and warn** the user. Do not proceed to the final report until resolved.
- If no numeric claims exist: skip this phase.

**Empirical motivation:** In our April 2026 NeurIPS submission, the final paper claimed `w in {0,1,2,3}` for the width-tradeoff experiment but the raw JSON had `w in {0,1,2,3,4,5}`. The crossing-point tolerance was claimed as `0.05%` but the actual relative error was `0.0577%`. Both were caught only after manual `paper-claim-audit` invocation in the final round; the improvement loop did not detect them.

### Phase 5.7: Citation Audit (if assurance = submission OR bib has `\cite`)

Invoke `/citation-audit` to verify every `\cite{...}` in the paper across three axes (existence / metadata / context). See `/citation-audit` skill for the full protocol.

```
/citation-audit paper/
```

The skill emits `paper/CITATION_AUDIT.json` (machine-readable, per `shared-references/assurance-contract.md` schema) and `paper/CITATION_AUDIT.md` (human-readable). Wrong-context citations (cited paper does not establish the claim) are the most dangerous bibliography bug — this phase catches them before submission.

**Activation predicate** (per integration-contract §1): runs unconditionally at `assurance: submission`; at `assurance: draft` runs if the bib file contains any entries. If `paper/references.bib` is absent and no `\cite{...}` exists in any `sections/*.tex`, citation-audit emits `NOT_APPLICABLE` and exits cleanly.

**Always emit, never block**: this phase writes the JSON artifact; the decision to block the Final Report lives in Phase 6 (the verifier + assurance combination). At `draft`, `FAIL` is advisory; at `submission`, `FAIL` blocks.

### Phase 6: External Audit Verifier + Final Report

**Pre-flight checklist** (per `../shared-references/integration-contract.md` §4 — visible to prevent lazy skipping):

```
📋 Submission audits required before Final Report (at assurance: submission):

  Always-on:
   [ ] 1. /proof-checker     → paper/PROOF_AUDIT.json
   [ ] 2. /paper-claim-audit → paper/PAPER_CLAIM_AUDIT.json
   [ ] 3. /citation-audit    → paper/CITATION_AUDIT.json

  Auto-fan-out per project contract (v2.2+ — only when frameworks declared):
   [ ] 4. If language=cpp        → /cpp-build, /cpp-sanitize, /cpp-bench
   [ ] 5. If frameworks: cuda    → /cuda-build, /cuda-sanitize, /cuda-profile, /cuda-correctness-audit
   [ ] 6. If frameworks: ros2    → /ros2-build, /ros2-launch-test, /ros2-realtime-audit
   [ ] 7. If frameworks: tensorrt → /tensorrt-engine-audit
   [ ] 8. If asymptotic claims present (\mathcal{O} / \Theta / \Omega) → /complexity-claim-audit

  Verifier:
   [ ] 9.  bash tools/verify_paper_audits.sh paper/ --assurance submission
   [ ] 10. Block Final Report iff verifier exit code != 0
```

All audits follow the "always emit, never block" contract (`shared-references/assurance-contract.md`). They write JSON artifacts at `paper/*_AUDIT.json`; the parent (this phase) decides blocking via the verifier.

**Step 6.-1 — Auto-fan-out (v2.2+, before invoking the verifier at submission)**:

When `assurance: submission`, **before** running `verify_paper_audits.sh`, fan out to the domain-specific audit skills based on the project contract. This makes `/paper-writing — assurance: submission` a true one-click submission gate — the user does not have to remember to call each `/cpp-*` / `/ros2-*` / `/cuda-*` skill manually.

```bash
# Read the project contract (CLAUDE.md > .aris/project.yaml > auto-detect)
LANG=$(python3 tools/project_contract.py get-language)
FRAMEWORKS=$(python3 tools/project_contract.py get-frameworks)

# Always — domain-agnostic core (already documented in Phases 4.5 / 4.7 / 5.5 / 5.7)
# /proof-checker /paper-claim-audit /citation-audit

# C++ project audits (when language=cpp)
if [[ "$LANG" == "cpp" ]]; then
  /cpp-build       # → BUILD_ARTIFACT.json
  /cpp-sanitize    # → SANITIZER_AUDIT.json (blocks on findings)
  /cpp-bench       # → BENCHMARK_RESULT.json (CV stability gate)
fi

# CUDA project audits (when frameworks contains cuda)
if echo " $FRAMEWORKS " | grep -q " cuda "; then
  /cuda-build              # → CUDA_BUILD_ARTIFACT.json
  /cuda-sanitize           # → CUDA_SANITIZER_AUDIT.json (blocks on race/oob)
  /cuda-profile            # → CUDA_PROFILE_REPORT.json (occupancy / DRAM throughput evidence)
  /cuda-correctness-audit  # → CUDA_CORRECTNESS_AUDIT.json (GPU vs CPU equivalence)
fi

# ROS2 project audits (when frameworks contains ros2)
if echo " $FRAMEWORKS " | grep -q " ros2 "; then
  /ros2-build              # → ROS2_BUILD_ARTIFACT.json
  /ros2-launch-test        # → ROS2_LAUNCH_TEST_AUDIT.json (QoS / TF / discovery)
  /ros2-realtime-audit     # → ROS2_REALTIME_AUDIT.json (p99 latency / control-loop freq)
fi

# TensorRT engine audit (when frameworks contains tensorrt)
if echo " $FRAMEWORKS " | grep -q " tensorrt "; then
  /tensorrt-engine-audit   # → TRT_ENGINE_AUDIT.json
fi

# Complexity-claim audit — opt-in, only fires if the paper has \mathcal{O} / \Theta / \Omega
if grep -qE '\\\\(mathcal\\{O\\}|Theta|Omega)|O\\(' paper/sections/*.tex paper/main.tex 2>/dev/null; then
  /complexity-claim-audit  # → COMPLEXITY_AUDIT.json
fi
```

Skip Step 6.-1 entirely when `assurance: draft` — the user can opt in to any individual audit at draft level but the executor does not auto-fan-out.

Each fan-out call follows the existing per-finding verification + dispute protocol (see `shared-references/codex-context-integrity.md`); a `FAIL` verdict from any audit is surfaced and disputed once before being treated as a blocker.

**Step 6.0 — Invoke the verifier**:

```bash
ASSURANCE="$(cat paper/.aris/assurance.txt 2>/dev/null || echo draft)"
bash tools/verify_paper_audits.sh paper/ --assurance "$ASSURANCE" \
    --json-out paper/.aris/audit-verifier-report.json
VERIFIER_EXIT=$?
```

The verifier:
1. Locates the three mandatory audit JSONs (`PROOF_AUDIT.json`, `PAPER_CLAIM_AUDIT.json`, `CITATION_AUDIT.json`)
2. Validates each against the schema in `shared-references/assurance-contract.md`
3. Rehashes every file in `audited_input_hashes` to detect STALE audits (user edited paper after audit ran)
4. Verifies each `trace_path` exists and is non-empty
5. Emits structured JSON report to `paper/.aris/audit-verifier-report.json`
6. Returns exit code: **0** (all green) or **1** (any FAIL/BLOCKED/ERROR/STALE/missing at submission level)

**Step 6.1 — Branch on verifier exit code**:

```
if assurance == "submission" AND VERIFIER_EXIT != 0:
    Final Report: REFUSED
    - Print the verifier's JSON report to surface which audit failed
    - Mark paper as `submission-ready: no` in the report below
    - Instruct the user: "Rerun the failed audit(s), or downgrade with --assurance draft"
    - Do NOT emit main.pdf as "submission-ready"

if assurance == "submission" AND VERIFIER_EXIT == 0:
    Final Report: submission-ready: yes
    - All three mandatory audit JSONs exist, schema-valid, fresh
    - Include verifier's JSON report as an appendix

if assurance == "draft":
    Final Report: draft-ready: yes
    - Verifier's exit code is advisory only
    - If exit != 0, log a warning but proceed
    - Mark paper as `draft-ready` (not `submission-ready`)
```

**Step 6.2 — Write the Final Report**:

```markdown
# Paper Writing Pipeline Report

**Input**: [NARRATIVE_REPORT.md or topic]
**Venue**: [ICLR/NeurIPS/ICML/CVPR/ACL/AAAI/ACM/IEEE_JOURNAL/IEEE_CONF]
**Assurance**: [draft | submission]   ← from paper/.aris/assurance.txt
**Submission-ready**: [yes | no | draft-ready]   ← from verifier exit code
**Date**: [today]

## Pipeline Summary

| Phase | Status | Output |
|-------|--------|--------|
| 0. Assurance Resolution | ✅ | paper/.aris/assurance.txt |
| 0.5. Wiki Context Load | ✅ | NARRATIVE_REPORT.md § Wiki-Sourced Positioning |
| 1. Paper Plan | ✅ | PAPER_PLAN.md |
| 2. Figures | ✅ | figures/ ([N] auto + [M] manual) |
| 3. LaTeX Writing | ✅ | paper/sections/*.tex ([N] sections, [M] citations) |
| 4. Compilation | ✅ | paper/main.pdf ([X] pages) |
| 4.5. Proof Audit | [PASS/WARN/FAIL/N/A/BLOCKED/ERROR] | paper/PROOF_AUDIT.json |
| 4.7. Claim Audit (pre) | [PASS/WARN/FAIL/N/A/BLOCKED/ERROR] | paper/PAPER_CLAIM_AUDIT.json |
| 5. Improvement | ✅ | [score0]/10 → [score2]/10 |
| 5.5. Claim Audit (post) | [PASS/WARN/FAIL/N/A/BLOCKED/ERROR] | paper/PAPER_CLAIM_AUDIT.json (re-run) |
| 5.7. Citation Audit | [PASS/WARN/FAIL/N/A/BLOCKED/ERROR] | paper/CITATION_AUDIT.json |
| 6. Verifier | [exit 0 / exit 1] | paper/.aris/audit-verifier-report.json |

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
- [ ] Add any missing manual figures
- [ ] Submit to [venue] via OpenReview / CMT / HotCRP
```

## Output Protocols

> Follow these shared protocols for all output files:
> - **[Output Versioning Protocol](../shared-references/output-versioning.md)** -- write timestamped file first, then copy to fixed name
> - **[Output Manifest Protocol](../shared-references/output-manifest.md)** -- log every output to MANIFEST.md
> - **[Output Language Protocol](../shared-references/output-language.md)** -- note: paper-writing always outputs English LaTeX for venue submission

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
