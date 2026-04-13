---
name: result-to-claim
description: Use when experiments complete to judge what claims the results support, what they don't, and what evidence is still missing. Codex CLI evaluates results against intended claims and routes to next action (pivot, supplement, or confirm). Use after experiments finish — before writing the paper or running ablations.
argument-hint: [experiment-description-or-wandb-run]
allowed-tools: Bash(*), Bash(codex*), Read, Grep, Glob, Write, Edit, Skill(codex:rescue), Skill(codex:adversarial-review)
---

# Result-to-Claim Gate

Experiments produce numbers; this gate decides what those numbers *mean*. Collect results from available sources, get a Codex judgment, then auto-route based on the verdict.

## Context: $ARGUMENTS

## When to Use

- After a set of experiments completes (main results, not just sanity checks)
- Before committing to claims in a paper or review response
- When results are ambiguous and you need an objective second opinion

## Workflow

### Step 1: Collect Results

Gather experiment data from whatever sources are available in the project:

1. **W&B** (preferred): `wandb.Api().run("<entity>/<project>/<run_id>").history()` — metrics, training curves, comparisons
2. **EXPERIMENT_LOG.md**: full results table with baselines and verdicts
3. **EXPERIMENT_TRACKER.md**: check which experiments are DONE vs still running
4. **Log files**: `ssh server "tail -100 /path/to/training.log"` if no other source
5. **docs/research_contract.md**: intended claims and experiment design

Assemble the key information:
- What experiments were run (method, dataset, config)
- Main metrics and baseline comparisons (deltas)
- The intended claim these experiments were designed to test
- Any known confounds or caveats

### Step 2: Codex Judgment

Send the collected results to Codex for objective evaluation:

```bash
codex exec --output-schema skills/shared-references/codex-schemas/claim-assessment.schema.json -o /tmp/aris-claims.json --sandbox read-only -m gpt-5.4 "RESULT-TO-CLAIM EVALUATION. Read the project files directly.

I need you to judge whether experimental results support the intended claim.

Intended claim: [the claim these experiments test]

Experiments run:
[list experiments with method, dataset, metrics]

Results:
[paste key numbers, comparison deltas, significance]

Baselines:
[baseline numbers and sources — reproduced or from paper]

Known caveats:
[any confounding factors, limited datasets, missing comparisons]

Please evaluate:
1. claim_supported: yes | partial | no
2. what_results_support: what the data actually shows
3. what_results_dont_support: where the data falls short of the claim
4. missing_evidence: specific evidence gaps
5. suggested_claim_revision: if the claim should be strengthened, weakened, or reframed
6. next_experiments_needed: specific experiments to fill gaps (if any)
7. confidence: high | medium | low

Be honest. Do not inflate claims beyond what the data supports.
A single positive result on one dataset does not support a general claim."
```

### Step 3: Parse and Normalize

Extract structured fields from Codex response:

```markdown
- claim_supported: yes | partial | no
- what_results_support: "..."
- what_results_dont_support: "..."
- missing_evidence: "..."
- suggested_claim_revision: "..."
- next_experiments_needed: "..."
- confidence: high | medium | low
```

### Step 4: Route Based on Verdict

#### `no` — Claim not supported

**Step 4a: Deep Failure Analysis** (codex:rescue — GPT-5.4 independently investigates why the idea failed):

```
/codex:rescue --effort xhigh "An idea has FAILED experimental validation. Perform a deep failure analysis.

Read these files directly:
- All experiment result files (JSON/CSV in results/ or refine-logs/)
- Source code in src/ — the implementation of the failed method
- refine-logs/EXPERIMENT_PLAN.md — what was planned
- refine-logs/FINAL_PROPOSAL.md — the method design
- IDEA_REPORT.md or research-wiki/ideas/ — the original idea

Analyze:
1. IMPLEMENTATION ANALYSIS: Was the idea implemented correctly? Any bugs, misunderstandings of the method, or shortcuts that deviated from the original design?
2. INTEGRATION ANALYSIS: Was the idea integrated into the codebase properly? Any conflicts with existing components, wrong API usage, or architectural mismatches?
3. ROOT CAUSE: Why did this idea fail? Distinguish between:
   - Implementation error (idea is sound but code is wrong)
   - Integration error (idea is sound but doesn't fit the current architecture)
   - Fundamental flaw (the idea's core assumption is wrong for this problem)
   - Insufficient tuning (idea might work with different hyperparameters/config)
   - Wrong evaluation (metrics don't capture what the idea improves)
4. SALVAGE ASSESSMENT: Is there a better way to implement or integrate this idea? Propose a concrete revised approach if the idea is salvageable.
5. LESSONS: What should we learn from this failure for future ideas?

Produce a structured FAILURE ANALYSIS REPORT."
```

Save the rescue report to `findings.md` under `## Failure Analysis: [idea name]`.

**Step 4b: Route based on analysis:**
- **Implementation/integration error** → fix the implementation → **mandatory `/codex:adversarial-review --scope working-tree`** → re-run experiment (don't abandon the idea)
- **Insufficient tuning** → run hyperparameter sweep → re-evaluate
- **Wrong evaluation** → change metrics/evaluation code → **mandatory `/codex:adversarial-review --scope working-tree`** → re-evaluate
- **Fundamental flaw** → record postmortem, pivot to next idea
- **Salvageable with revised approach** → implement the revised approach → **mandatory `/codex:adversarial-review --scope working-tree`** → re-run

> **Rule: ANY code change before re-running experiments must pass adversarial review. No exceptions.**

1. Record postmortem in findings.md (Research Findings section):
   - What was tested, what failed, rescue's root cause analysis
   - Constraints for future attempts (what NOT to try again)
   - If salvageable: the revised approach proposed by rescue
2. Update `CODEX.md` `## Pipeline Status` (fallback to `CLAUDE.md` only if the project still uses the legacy filename)
3. Decide: fix implementation / try revised approach / pivot to next idea from IDEA_CANDIDATES.md

#### `partial` — Claim partially supported

**Step 4a: Partial Failure Investigation** (codex:rescue):
```
/codex:rescue --effort xhigh "An idea shows PARTIAL results. Read these files directly:
- All experiment result files (JSON/CSV in results/ or refine-logs/)
- Source code in src/ — the implementation
- refine-logs/EXPERIMENT_PLAN.md — what was planned
- refine-logs/FINAL_PROPOSAL.md — the method design
Analyze: (1) Which aspects work and which don't? (2) Is the partial failure due to implementation issues, integration problems, or narrower applicability? (3) Propose specific fixes to close the gap."
```

1. Update the working claim to reflect what IS supported
2. Record the gap + rescue analysis in findings.md
3. If rescue identifies implementation/integration issues → fix → **mandatory `/codex:adversarial-review --scope working-tree`** → re-run
4. If rescue suggests the idea has narrower scope → narrow the claim, design supplementary experiments
5. Re-run result-to-claim after fixes/supplementary experiments complete
6. **Multiple rounds of `partial` on the same claim** → escalate to `/codex:rescue --effort xhigh` for deeper investigation of why the gap persists

#### `yes` — Claim supported

1. Record confirmed claim in project notes
2. If ablation studies are incomplete → trigger `/ablation-planner`
3. If all evidence is in → ready for paper writing

### Step 5: Research Wiki Update (if `research-wiki/` exists)

**Skip entirely if `research-wiki/` directory does not exist.**

After the verdict, update the wiki with experiment results and claim status:

```bash
# 1. Create experiment page
# research-wiki/experiments/<exp_id>.md with: metrics, verdict, confidence

# 2. Update claim status
if verdict == "yes":
    python3 tools/research_wiki.py add_edge research-wiki/ \
      --from "exp:<id>" --to "claim:<cid>" --type "supports" --evidence "<metric_delta>"
elif verdict == "partial":
    python3 tools/research_wiki.py add_edge research-wiki/ \
      --from "exp:<id>" --to "claim:<cid>" --type "supports" --evidence "partial"
else:  # verdict == "no"
    python3 tools/research_wiki.py add_edge research-wiki/ \
      --from "exp:<id>" --to "claim:<cid>" --type "invalidates" --evidence "<why_failed>"

# 3. Update idea outcome (positive/mixed/negative)
# 4. Rebuild query_pack and log
python3 tools/research_wiki.py rebuild_query_pack research-wiki/
python3 tools/research_wiki.py log research-wiki/ "result-to-claim: exp:<id> verdict=<verdict>"

# 5. If >= 3 failed ideas since last ideation → suggest re-running /idea-creator
```

## Rules

- **Codex CLI is the judge, not CC.** CC collects evidence and routes; Codex evaluates. This prevents post-hoc rationalization.
- Do not inflate claims beyond what the data supports. If Codex says "partial", do not round up to "yes".
- A single positive result on one dataset does not support a general claim. Be honest about scope.
- If `confidence` is low, treat the judgment as inconclusive and add experiments rather than committing to a claim.
- If Codex CLI is unavailable (call fails), CC makes its own judgment and marks it `[pending Codex review]` — do not block the pipeline.
- Always record the verdict and reasoning in findings.md, regardless of outcome.
