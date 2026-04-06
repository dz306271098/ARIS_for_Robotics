---
name: experiment-bridge
description: "Workflow 1.5: Bridge between idea discovery and auto review. Reads EXPERIMENT_PLAN.md, implements experiment code, deploys to GPU, collects initial results. Use when user says \"实现实验\", \"implement experiments\", \"bridge\", \"从计划到跑实验\", \"deploy the plan\", or has an experiment plan ready to execute."
argument-hint: [experiment-plan-path-or-topic]
allowed-tools: Bash(*), Read, Write, Edit, Grep, Glob, Agent, Skill, mcp__codex__codex, mcp__codex__codex-reply
---

# Workflow 1.5: Experiment Bridge

Implement and deploy experiments from plan: **$ARGUMENTS**

## Overview

This skill bridges Workflow 1 (idea discovery + method refinement) and Workflow 2 (auto review loop). It takes the experiment plan and turns it into running experiments with initial results.

```
Workflow 1 output:                    This skill:                                    Workflow 2 input:
refine-logs/EXPERIMENT_PLAN.md   →   implement → GPT-5.4 review → deploy → collect → initial results ready
refine-logs/EXPERIMENT_TRACKER.md     code        (cross-model)    /run-experiment     for /auto-review-loop
refine-logs/FINAL_PROPOSAL.md
```

## Constants

- **CODE_REVIEW = true** — GPT-5.4 xhigh reviews experiment code before deployment. Catches logic bugs before wasting GPU hours. Set `false` to skip.
- **AUTO_DEPLOY = true** — Automatically deploy experiments after implementation + review. Set `false` to manually inspect code before deploying.
- **SANITY_FIRST = true** — Run the sanity-stage experiment first (smallest, fastest) before launching the rest. Catches setup bugs early.
- **MAX_PARALLEL_RUNS = 4** — Maximum number of experiments to deploy in parallel (limited by available GPUs).
- **BASE_REPO = false** — GitHub repo URL to use as base codebase. When set, clone the repo first and implement experiments on top of it. When `false` (default), write code from scratch or reuse existing project files.
- **COMPACT = false** — When `true`, (1) read `IDEA_CANDIDATES.md` instead of full `IDEA_REPORT.md` if available, (2) append experiment results to `EXPERIMENT_LOG.md` after collection.
- **BASELINE_COMPARISON = ""** — When set (e.g., "AIR-IO"), automatically include this baseline in all comparison tables. Compute delta metrics (Δ = method - baseline) with significance indicators.
- **ITERATIVE_VARIANTS = false** — When `true`, support testing multiple method variants within the same bridge session. Useful for rapid variant comparison during deep innovation loops.

> Override: `/experiment-bridge "EXPERIMENT_PLAN.md" — compact: true, base repo: https://github.com/org/project`

## Inputs

This skill expects one or more of:

1. **`refine-logs/EXPERIMENT_PLAN.md`** (best) — claim-driven experiment roadmap from `/experiment-plan`
2. **`refine-logs/EXPERIMENT_TRACKER.md`** — run-by-run execution table
3. **`refine-logs/FINAL_PROPOSAL.md`** — method description for implementation context
4. **`IDEA_CANDIDATES.md`** — compact idea summary (preferred when `COMPACT: true`)
5. **`IDEA_REPORT.md`** — full brainstorm output (fallback)

If none exist, autonomously infer experiments from available context: read `IDEA_REPORT.md`, `RESEARCH_BRIEF.md`, `CLAUDE.md`, and any existing code to design a minimal experiment plan. Document the auto-generated plan before proceeding. Only ask the user if there is truly no project context to work from.

## Workflow

### Phase 1: Parse the Experiment Plan

Read `EXPERIMENT_PLAN.md` and extract:

1. **Run order and milestones** — which experiments run first (sanity → baseline → main → ablation → polish)
2. **For each experiment block:**
   - Dataset / split / task
   - Compared systems and variants
   - Metrics to compute
   - Setup details (backbone, hyperparameters, seeds)
   - Success criterion
   - Priority (MUST-RUN vs NICE-TO-HAVE)
3. **Compute budget** — total estimated GPU-hours
4. **Method details** from `FINAL_PROPOSAL.md` — what exactly to implement

Present a brief summary:

```
📋 Experiment plan loaded:
- Milestones: [N] (sanity → baseline → main → ablation)
- Must-run experiments: [N]
- Nice-to-have: [N]
- Estimated GPU-hours: [X]

Proceeding to implementation.
```

### Phase 2: Implement Experiment Code

**If `BASE_REPO` is set** — clone the repo first:
```bash
git clone <BASE_REPO> base_repo/
# Read the repo's README, understand its structure, find entry points
# Implement experiments by modifying/extending this codebase
```

For each milestone (in order), write the experiment scripts:

1. **Check existing code** — scan the project (or cloned `base_repo/`) for existing experiment scripts, model code, data loaders. Reuse as much as possible.

2. **Implement missing pieces:**
   - Training scripts with proper argparse (all hyperparameters configurable)
   - Evaluation scripts computing the specified metrics
   - Data loading / preprocessing if needed
   - Baseline implementations if not already present
   - Fixed random seeds for reproducibility
   - Results saved to JSON/CSV for later analysis
   - Proper logging (wandb if configured in CLAUDE.md)

3. **Follow the plan's run order** — implement sanity-stage experiments first, then baselines, then main method, then ablations.

4. **Self-review before deploying:**
   - Are all hyperparameters from EXPERIMENT_PLAN.md reflected in argparse?
   - Is the random seed fixed and controllable?
   - Are results saved in a parseable format (JSON/CSV)?
   - Does the code match FINAL_PROPOSAL.md's method description?

### Phase 2.5: Cross-Model Code Review (when CODE_REVIEW = true)

**Skip this step if `CODE_REVIEW` is `false`.**

**Step 2.5a: Independent Code Audit** (Codex Plugin — GPT-5.4 reads actual code directly):

See `../shared-references/codex-context-integrity.md` for channel selection rules.

```
/codex:adversarial-review --scope working-tree --focus "Review experiment implementation for: baseline fairness (same tuning budget, training schedule, data splits across all methods), statistical rigor (>= 3 seeds, mean +/- std, significance tests), correct ground truth usage (NOT another model's output), data leakage between train/test, fair hyperparameter tuning"
```

If adversarial-review returns `needs-attention` with CRITICAL findings: fix them before proceeding. Append ALL findings to the MCP review context below.

**Step 2.5b: Design Review** (MCP dialogue — for methodology discussion):

Send the experiment **design AND code** to GPT-5.4 xhigh for review:

```
mcp__codex__codex:
  config: {"model_reasoning_effort": "xhigh"}
  prompt: |
    Review the following experiment DESIGN and IMPLEMENTATION for correctness.
    Act as a devil's advocate — find problems BEFORE we waste GPU hours.

    ## Experiment Plan:
    [paste key sections from EXPERIMENT_PLAN.md]

    ## Method Description:
    [paste from FINAL_PROPOSAL.md]

    ## Implementation:
    [paste the experiment scripts]

    ## PART 1 — EXPERIMENT DESIGN REVIEW:
    1. Does the experiment actually test the stated claims?
    2. Are the chosen baselines the STRONGEST available, or are weak 
       baselines cherry-picked to make our method look better?
    3. Are the evaluation metrics standard for this field? Would a 
       different metric tell a different story?
    4. BASELINE FAIRNESS AUDIT — for each baseline, verify ALL of:
       a. Hyperparameter parity: was the baseline given the same tuning budget as the proposed method?
       b. Training schedule alignment: same epochs/steps, same LR schedule type, same warmup?
       c. Data parity: identical train/val/test splits, same preprocessing, same data augmentation?
       d. Compute parity: same model size class (param count within 2x), same hardware for timing?
       e. Code provenance: official code or re-implemented? If re-implemented, validated against published numbers?
       f. Recency: are baselines from the last 2 years? Cite the strongest known result.
       For each violation: classify as CRITICAL (invalidates comparison) or MINOR (document in paper).
    5. STATISTICAL RIGOR CHECK:
       - Are there >= 3 seeds for all stochastic experiments?
       - Does the evaluation code compute mean ± std?
       - For the main comparison: does it compute 95% confidence intervals?
       - For close results (delta < 2× std): is a significance test implemented (paired t-test or Wilcoxon)?
       - Do plotting scripts include error bars/shaded regions?
       - Is the error bar type documented (std, SEM, or CI)?
    6. What is the most likely way a reviewer would attack this 
       experimental setup?

    ## PART 2 — CODE REVIEW:
    1. Does the code correctly implement the method described in the proposal?
    2. Are all hyperparameters from the plan reflected in the code?
    3. Are there any logic bugs (wrong loss function, incorrect data split, missing eval)?
    4. Is the evaluation metric computed correctly?
    5. **CRITICAL: Does evaluation use the dataset's actual ground truth labels — NOT another model's output as ground truth?** This is a common and severe bug.
    6. Any potential issues (OOM risk, numerical instability, missing seeds)?

    For each issue found, specify: CRITICAL / MAJOR / MINOR and the exact fix.
```

**On review results:**
- **No CRITICAL issues** → proceed to Phase 3
- **CRITICAL issues found** → fix them, then re-submit for review (max 2 rounds)
- **Codex MCP unavailable** → skip silently, proceed to Phase 3 (graceful degradation)

### Phase 3: Sanity Check (if SANITY_FIRST = true)

Before deploying the full experiment suite, run the sanity-stage experiment:

```
/run-experiment [sanity experiment command]
```

Wait for completion. Verify:
- Training loop runs without errors
- Metrics are computed and saved correctly
- GPU memory usage is within bounds
- Output format matches expectations

If sanity fails → **auto-debug before giving up** (max 3 attempts):

1. **Read the error** — parse traceback, stderr, and log files
2. **Diagnose** — classify the failure:
   - OOM → reduce batch size or enable gradient checkpointing
   - ImportError → install missing package
   - FileNotFoundError → fix path or download data
   - CUDA error → check GPU availability, reduce model size
   - NaN/divergence → reduce learning rate, check data preprocessing
3. **Fix and re-run** — apply the fix, re-run sanity
4. **Still failing after 3 attempts?** → stop, report the failure with all attempted fixes and error logs. Do not proceed with broken code.

> Never give up on the first failure. Most experiment crashes are fixable without human intervention.

### Phase 4: Deploy Full Experiments

Deploy experiments following the plan's milestone order:

```
/run-experiment [experiment commands]
```

For each milestone:
1. Deploy experiments in parallel (up to MAX_PARALLEL_RUNS)
2. Use `/monitor-experiment` to track progress
3. Collect results as experiments complete

**🚦 Checkpoint (if AUTO_DEPLOY = false):**

```
🔧 Code implementation complete. Ready to deploy:

Milestone 0 (sanity): [status — passed/pending]
Milestone 1 (baseline): [N experiments, ~X GPU-hours]
Milestone 2 (main method): [N experiments, ~X GPU-hours]
Milestone 3 (ablations): [N experiments, ~X GPU-hours]

Total estimated: ~X GPU-hours on [N] GPUs

Deploy now? Or review the code first?
```

### Phase 5: Collect Initial Results

As experiments complete:

1. **Parse output files** (JSON/CSV/logs) for key metrics
2. **Training quality check** — if W&B data is available (CLAUDE.md has `wandb: true` and `wandb_project`), invoke `/training-check` to detect NaN, loss divergence, plateaus, or overfitting. If W&B is not configured, skip silently.
3. **Update `refine-logs/EXPERIMENT_TRACKER.md`** — fill in Status and Notes columns
4. **Check success criteria** from EXPERIMENT_PLAN.md — did each experiment meet its bar?
4. **Write initial results summary:**

```markdown
# Initial Experiment Results

**Date**: [today]
**Plan**: refine-logs/EXPERIMENT_PLAN.md

## Results by Milestone

### M0: Sanity — PASSED
- [result]

### M1: Baselines
| Run | System | Key Metric | Status |
|-----|--------|-----------|--------|
| R001 | baseline_1 | X.XX | DONE |

### M2: Main Method
| Run | System | Key Metric | Status |
|-----|--------|-----------|--------|
| R003 | our_method | X.XX | DONE |

### M3: Ablations
...

## Summary
- [X/Y] must-run experiments completed
- Main result: [positive/negative/inconclusive]
- Ready for /auto-review-loop: [YES/NO]

## Next Step
→ /auto-review-loop "[topic]"
```

### Baseline Comparison (when BASELINE_COMPARISON is set)

After collecting results, automatically:
1. Ensure baseline (e.g., AIR-IO) results are included in comparison
2. If baseline results not available: run baseline evaluation first
3. Compute delta metrics: Δ = (method - baseline) for each metric
4. Add significance indicator: * for p < 0.05, ** for p < 0.01
5. Format comparison table:
   | Method | ATE (m) ↓ | RTE (m/s) ↓ | Drift (%) ↓ | vs Baseline |
   |--------|-----------|-------------|-------------|-------------|
   | [Baseline] | X.XX | X.XX | X.XX | — |
   | Ours (vN) | X.XX | X.XX | X.XX | ΔX.XX (±X%) |

### Phase 5.45: Independent Result Interpretation (Codex Plugin)

Let GPT-5.4 independently read and interpret the raw experiment results:

```
/codex:rescue --effort high "Read the experiment results in refine-logs/EXPERIMENT_RESULTS.md and any raw output files (JSON/CSV). Independently assess: (1) Do results support the stated hypothesis? (2) Are there red flags (unusual variance, suspiciously perfect numbers, unfair comparisons)? (3) Are baseline comparisons valid? (4) What additional experiments would strengthen the evidence?"
```

Append rescue findings to the results summary. If rescue flags critical issues (e.g., unfair baselines, data leakage), these must be addressed before handoff.

### Phase 5.5: Write Compact Log (when COMPACT = true)

**Skip entirely if `COMPACT` is `false`.**

Append each completed experiment to `EXPERIMENT_LOG.md`:

```markdown
## [Run ID] — [timestamp]
- **System**: [method name]
- **Config**: [key hyperparameters]
- **Result**: [primary metric = X.XX]
- **Verdict**: [positive / negative / inconclusive]
- **Reproduce**: `python train.py --config configs/run_id.yaml --seed 42`
```

This structured log survives session recovery — downstream skills read it instead of parsing screen output.

### Phase 5.6: Auto Ablation Planning

After main experiments (M2) complete with positive results, invoke `/ablation-planner` to design ablation studies:

- Read the main results and method description
- Generate a claim-driven ablation plan: which components to remove, what to compare, expected outcomes
- Append ablation blocks to `refine-logs/EXPERIMENT_PLAN.md` and `refine-logs/EXPERIMENT_TRACKER.md`
- If main results are negative or inconclusive, skip ablation planning and note in the summary

If `/ablation-planner` is not available, skip silently — the existing EXPERIMENT_PLAN.md ablation blocks (if any) remain unchanged.

### Phase 5.7: Principle-Guided Diagnosis (when main results are negative)

**Skip entirely if main results are positive.**

When the main method produces negative or inconclusive results, consult literature for inspiration before handing off:

1. **Diagnose the failure**: What specific metric fell short? On which data splits or scenarios?

2. **Identify the root cause**: Why did the method underperform? Trace from the symptom to the underlying mathematical, physical, or architectural reason.

3. **Quick literature scan**: Search for techniques addressing this specific root cause:
   ```bash
   python tools/arxiv_fetch.py search "[root cause keywords]" --max 10
   python tools/semantic_scholar_fetch.py search "[root cause keywords]" --max 10 --year "2024-"
   ```
   **Web resilience**: If searches hang (~60s), abandon and skip. This phase is advisory, not blocking.

4. **Extract principles** (not methods): For the 2-3 most relevant papers found, apply the Principle Extraction Protocol from `../shared-references/principle-extraction.md`:
   - Layer 2: What is the underlying principle? (WHY does this work, one sentence, no paper nouns)
   - Layer 4: How does this principle adapt to our problem?
   - Layer 5: What must NOT be copied?

5. **Document in results summary**: Append a `## Failure Diagnosis and Principles for Retry` section:
   ```markdown
   ## Failure Diagnosis and Principles for Retry
   
   - **Symptom**: [what went wrong]
   - **Root cause**: [why]
   - **Relevant principles from literature**:
     1. [Principle name]: [one-sentence generalized insight] — adaptation: [how it could help our method]
     2. [Principle name]: [one-sentence generalized insight] — adaptation: [how it could help our method]
   - **Suggested next step**: /auto-review-loop or /deep-innovation-loop with these principles as starting context
   ```

This provides actionable principle-based intelligence for the downstream review loop rather than a bare "results were negative" handoff.

### Phase 6: Handoff

Present final status:

```
🔬 Experiment bridge complete:
- Implemented: [N] experiment scripts
- Deployed: [N] experiments on [M] GPUs
- Completed: [X/Y] must-run, [A/B] nice-to-have
- Main result: [one sentence]

Results: refine-logs/EXPERIMENT_RESULTS.md
Tracker: refine-logs/EXPERIMENT_TRACKER.md

Ready for Workflow 2:
→ /auto-review-loop "[topic]"
```

## Key Rules

- **Large file handling**: If the Write tool fails due to file size, immediately retry using Bash (`cat << 'EOF' > file`) to write in chunks. Do NOT ask the user for permission — just do it silently.
- **CRITICAL — Evaluation must use dataset ground truth.** When writing evaluation scripts, ALWAYS compare model predictions against the dataset's actual ground truth labels/targets — NEVER use another model's output as ground truth. Double-check: (1) ground truth comes from the dataset split, not from a baseline/backbone model, (2) evaluation metrics are computed against the same ground truth for all methods, (3) if the task has official eval scripts, use those.
- **Follow the plan.** Do not invent experiments not in EXPERIMENT_PLAN.md. If you think something is missing, note it but don't add it.
- **Sanity first.** Never deploy a full suite without verifying the sanity stage passes.
- **Reuse existing code.** Scan the project before writing new scripts. Extend, don't duplicate.
- **Save everything as JSON/CSV.** The auto-review-loop needs parseable results, not just terminal output.
- **Update the tracker.** `EXPERIMENT_TRACKER.md` should reflect real status after each run completes.
- **Don't wait forever.** If an experiment exceeds 2x its estimated time, flag it and move on to the next milestone.
- **Budget awareness.** Track GPU-hours against the plan's budget. Warn if approaching the limit.
- **Vast.ai lifecycle.** If using vast.ai instances, destroy them after all experiments complete and results are downloaded. Running instances cost money every second — don't leave them idle. Use `/vast-gpu destroy` or `/vast-gpu destroy-all` when done.

## Composing with Other Skills

```
/idea-discovery "direction"          ← Workflow 1: find + refine + plan
/experiment-bridge                   ← you are here (Workflow 1.5: implement + deploy)
/auto-review-loop "topic"            ← Workflow 2: review + iterate
/paper-writing "NARRATIVE_REPORT.md" ← Workflow 3: write the paper

Or use /research-pipeline for the full end-to-end flow (includes this bridge).
```
