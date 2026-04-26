---
name: experiment-plan
description: 'Turn a refined research proposal or method idea into a detailed, claim-driven experiment roadmap. Use after `research-refine`, or when the user asks for a detailed experiment plan, ablation matrix, evaluation protocol, run order, compute budget, or paper-ready validation that supports the core problem, novelty, simplicity, and any LLM / VLM / Diffusion / RL-based contribution.'
allowed-tools: Bash(*), Bash(codex*), Read, Write, Edit, Grep, Glob, WebSearch, WebFetch, Agent, Skill(codex:rescue), Skill(codex:adversarial-review)
---

# Experiment Plan: Claim-Driven, Paper-Oriented Validation

Refine and concretize: **$ARGUMENTS**

## Overview

Use this skill after the method is stable enough that the next question becomes: **what exact experiments should we run, in what order, to defend the paper?** If the user wants the full chain in one request, prefer `/research-refine-pipeline`.

The goal is not to generate a giant benchmark wishlist. The goal is to turn a proposal into a **claim -> evidence -> run order** roadmap that supports four things:

1. the method actually solves the anchored problem
2. the dominant contribution is real and focused
3. the method is elegant enough that extra complexity is unnecessary
4. any frontier-model-era component is genuinely useful, not decorative

## Constants

- **OUTPUT_DIR = `refine-logs/`** — Default destination for experiment planning artifacts.
- **MAX_PRIMARY_CLAIMS = 2** — Prefer one dominant claim plus one supporting claim.
- **MAX_CORE_BLOCKS = 5** — Keep the must-run experimental story compact.
- **MAX_BASELINE_FAMILIES = 3** — Prefer a few strong baselines over many weak ones.
- **DEFAULT_SEEDS = 3** — Use 3 seeds when stochastic variance matters and budget allows. Report mean ± std. For close comparisons: require significance test (paired t-test or Wilcoxon, p < 0.05).
- **HPARAM_SEARCH = true** — Plan hyperparameter sensitivity analysis for each novel component. Default method: small grid (3-5 values per parameter) on reduced dataset. For REFINE-phase experiments: expand to finer grid or random search.

## Workflow

### Phase 0: Load the Proposal Context

Read the most relevant existing files first if they exist:

- `refine-logs/FINAL_PROPOSAL.md`
- `refine-logs/REVIEW_SUMMARY.md`
- `refine-logs/REFINEMENT_REPORT.md`

Extract:

- **Problem Anchor**
- **Dominant contribution**
- **Optional supporting contribution**
- **Critical reviewer concerns**
- **Data / compute / timeline constraints**
- **Which frontier primitive is central, if any**

If these files do not exist, derive the same information from the user's prompt.

### Phase 1: Freeze the Paper Claims

Before proposing experiments, write down the claims that must be defended.

Use this structure:

- **Primary claim**: the main mechanism-level contribution
- **Supporting claim**: optional, only if it directly strengthens the main paper story
- **Anti-claim to rule out**: e.g. "the gain only comes from more parameters," "the gain only comes from a larger search space," or "the modern component is just decoration"
- **Minimum convincing evidence**: what would make each claim believable to a strong reviewer?

Do not exceed `MAX_PRIMARY_CLAIMS` unless the paper truly has multiple inseparable claims.

### Phase 2: Build the Experimental Storyline

Design the paper around a compact set of experiment blocks. Default to the following blocks and delete any that are not needed:

1. **Main anchor result** — does the method solve the actual bottleneck?
2. **Novelty isolation** — does the dominant contribution itself matter?
3. **Simplicity / elegance check** — can a bigger or more fragmented version be avoided?
4. **Frontier necessity check** — if an LLM / VLM / Diffusion / RL-era component is central, is it actually the right tool?
5. **Failure analysis or qualitative diagnosis** — what does the method still miss?

For each block, decide whether it belongs in:

- **Main paper** — essential to defend the core claims
- **Appendix** — useful but non-blocking
- **Cut** — interesting, but not worth the paper budget

Prefer one strong baseline family over many weak baselines. If a stronger modern baseline exists, use it instead of padding the list.

### Phase 3: Specify Each Experiment Block

For every kept block, fully specify:

- **Claim tested**
- **Why this block exists**
- **Dataset / split / task**
- **Compared systems**: strongest baselines, ablations, and variants only
- **Metrics**: decisive metrics first, secondary metrics second
- **Setup details**: backbone, frozen vs trainable parts, key hyperparameters, training budget, seeds
- **Hyperparameter sensitivity** (when HPARAM_SEARCH=true): list 2-3 key hyperparameters to sweep, range for each (e.g., "LR: {1e-4, 3e-4, 1e-3}"), method (grid/random), dataset for sweep (smallest available)
- **Statistical protocol**: number of seeds, what to report (mean ± std, CI, p-value for close comparisons), error bar type
- **Success criterion**: what outcome would count as convincing evidence?
- **Failure interpretation**: if the result is negative, what does it mean?
- **Table / figure target**: where this result should appear in the paper

Special rules:

- A **simplicity check** should usually compare the final method against either an overbuilt variant or a tempting extra component that the paper intentionally rejects.
- A **frontier necessity check** should usually compare the chosen modern primitive against the strongest plausible simpler or older alternative.
- If the proposal is intentionally non-frontier, say so explicitly and skip the frontier block instead of forcing one.

### Phase 4: Turn the Plan Into an Execution Order

Build a realistic run order so the user knows what to do first.

Use this milestone structure:

1. **Sanity stage** — data pipeline, metric correctness, one quick overfit or toy split
2. **Baseline stage** — reproduce the strongest baseline(s)
3. **Main method stage** — run the final method on the primary setting
4. **Decision stage** — run the decisive ablations for novelty, simplicity, and frontier necessity
5. **Polish stage** — robustness, qualitative figures, appendix extras

For each milestone, estimate:

- compute cost
- expected turnaround time
- stop / go decision gate
- risk and mitigation

Separate **must-run** from **nice-to-have** experiments.

### Phase 4.5: Adversarial Experiment Design Review (Codex CLI)

Before writing the outputs, submit the complete experiment plan to GPT-5.4 via Codex CLI for adversarial review:

```bash
codex exec --output-schema skills/shared-references/codex-schemas/design-review.schema.json -o /tmp/aris-plan-review.json --sandbox read-only -m gpt-5.4 "You are a senior reviewer at [target venue]. I am submitting an experiment plan for review. Your job is to find WEAKNESSES — act as a devil's advocate. Read the project files directly.

Method thesis: [one-sentence thesis]

Claims to defend:
[paste claim map]

Experiment blocks:
[paste all blocks with datasets, metrics, baselines, success criteria]

Run order and milestones:
[paste milestone plan]

TASK: Challenge this experiment plan adversarially.

1. MISSING EXPERIMENTS: What experiments are missing that a reviewer would demand? What baselines are suspiciously absent?
2. WEAK CONTROLS: Are the success criteria too lenient? Are metrics cherry-picked? Would a different metric tell a different story?
3. UNFAIR COMPARISONS: Are baselines given the same hyperparameter tuning budget? Same data augmentation? Same compute?
4. CLAIM-EVIDENCE GAPS: Which claims lack convincing evidence even if all experiments succeed?
5. STATISTICAL RIGOR: Are there enough seeds/runs? Is the evaluation protocol standard for the field?
6. BLIND SPOTS: What could go wrong that the plan doesn't account for?
7. VERDICT: Rate this plan 1-10 for convincing a top-venue reviewer. List the top 3 changes needed."
```

**After receiving feedback:**
1. For each critical issue raised: update the experiment plan to address it
2. Add missing baselines/experiments to the tracker
3. Tighten success criteria if they were too lenient
4. If the reviewer suggests cutting unnecessary experiments: remove them
5. Log the review feedback in `refine-logs/EXPERIMENT_PLAN.md` under a `## Codex Review` section

### Phase 5: Write the Outputs

#### Step 5.1: Write `refine-logs/EXPERIMENT_PLAN.md`

Use this structure:

```markdown
# Experiment Plan

**Problem**: [problem]
**Method Thesis**: [one-sentence thesis]
**Date**: [today]

## Claim Map
| Claim | Why It Matters | Minimum Convincing Evidence | Linked Blocks |
|-------|-----------------|-----------------------------|---------------|
| C1    | ...             | ...                         | B1, B2        |

## Paper Storyline
- Main paper must prove:
- Appendix can support:
- Experiments intentionally cut:

## Experiment Blocks

### Block 1: [Name]
- Claim tested:
- Why this block exists:
- Dataset / split / task:
- Compared systems:
- Metrics:
- Setup details:
- Success criterion:
- Failure interpretation:
- Table / figure target:
- Priority: MUST-RUN / NICE-TO-HAVE

### Block 2: [Name]
...

## Run Order and Milestones
| Milestone | Goal | Runs | Decision Gate | Cost | Risk |
|-----------|------|------|---------------|------|------|
| M0        | ...  | ...  | ...           | ...  | ...  |

## Compute and Data Budget
- Total estimated GPU-hours:
- Data preparation needs:
- Human evaluation needs:
- Biggest bottleneck:

## Risks and Mitigations
- [Risk]:
- [Mitigation]:

## Final Checklist
- [ ] Main paper tables are covered
- [ ] Novelty is isolated
- [ ] Simplicity is defended
- [ ] Frontier contribution is justified or explicitly not claimed
- [ ] Nice-to-have runs are separated from must-run runs
```

#### Step 5.2: Write `refine-logs/EXPERIMENT_TRACKER.md`

Use this structure:

```markdown
# Experiment Tracker

| Run ID | Milestone | Purpose | System / Variant | Split | Metrics | Priority | Status | Notes |
|--------|-----------|---------|------------------|-------|---------|----------|--------|-------|
| R001   | M0        | sanity  | ...              | ...   | ...     | MUST     | TODO   | ...   |
```

Keep the tracker compact and execution-oriented.

#### Step 5.3: Present a Brief Summary to the User

```
Experiment plan ready.

Must-run blocks:
- [Block 1]
- [Block 2]

Highest-risk assumption:
- [risk]

First three runs to launch:
1. [run]
2. [run]
3. [run]

Plan file: refine-logs/EXPERIMENT_PLAN.md
Tracker file: refine-logs/EXPERIMENT_TRACKER.md
```

## Key Rules

- **Large file handling**: If the Write tool fails due to file size, immediately retry using Bash (`cat << 'EOF' > file`) to write in chunks. Do NOT ask the user for permission — just do it silently.

- **Every experiment must defend a claim.** If it does not change a reviewer belief, cut it.
- **Prefer a compact paper story.** Design the main table first, then add only the ablations that defend it.
- **Defend simplicity explicitly.** If complexity is a concern, include a deletion study or a stronger-but-bloated variant comparison.
- **Defend frontier choices explicitly.** If a modern primitive is central, prove why it is better than the strongest simpler alternative.
- **Prefer strong baselines over long baseline lists.** A short, credible comparison set is better than a padded one.
- **Separate must-run from nice-to-have.** Do not let appendix ideas delay the core paper evidence.
- **Reuse proposal constraints.** Do not invent unrealistic budgets or data assumptions.
- **Do not fabricate results.** Plan evidence; do not claim evidence.

## Composing with Other Skills

```
/research-refine-pipeline -> one-shot method + experiment planning
/research-refine   -> method and claim refinement
/experiment-plan   -> detailed experiment roadmap
/run-experiment    -> execute the runs
/auto-review-loop  -> react to results and iterate on the paper
```

## Domain modes (v2.2+)

When `.aris/project.yaml` declares `language ≠ python` or `frameworks` includes `ros2` / `cuda`, pivot the "Metrics" and "Run order" sections per domain.

The domain keywords describe **project shape**, not research topic. Any C++ research project (SLAM, perception, NLP, LLM inference, graphics, HPC kernel, database, compiler, etc.) picks the mode matching how its code is organized:

- **`— domain: cpp-generic`** (default for any `language: cpp` project without specific framework flavor):
  - Metrics: pick from `{wall_time_ms, peak_rss_kb, cache_misses, instructions_retired, throughput_ops_sec, p99_latency_ms, model-specific quality metric}`; the domain is empirical, not inherently about asymptotic bounds.
  - Run order: correctness (sanitizers PASS) → baseline comparison at matched budget → ablations (compiler flags / data structures / algorithm variants / representative hyperparameters) → scalability study on the relevant inputs.
  - Claim surface: empirical deltas against baseline + reproducibility details. `/complexity-claim-audit` applies ONLY when the paper actually states `\mathcal{O}`/`\Theta`/`\Omega` bounds (common for theory / systems papers, uncommon for perception / NLP / SLAM).

- **`— domain: robotics`** (`frameworks: [ros2, ...]`, `venue_family: robotics`):
  - Metrics: `control_loop_freq_hz`, `topic_latency_p50_ms` / `p99_ms`, `tf_lookup_error_rate`, `node_uptime_s`, `sim_to_real_gap`, domain-specific success rate (e.g. ATE / RPE for SLAM, IoU for perception pipelines).
  - Run order: sim-only baseline → sim with ablations → real-robot (fewer trials) → sim-to-real gap analysis → failure-mode analysis.
  - Claim surface: real-time deadline + success rate + generalization across environments. Audited by `/ros2-launch-test` and `/ros2-realtime-audit`.

- **`— domain: gpu`** (`frameworks: [cuda, ...]`, `venue_family: gpu|hpc|ml`):
  - Metrics: `kernel_time_us`, `occupancy_pct`, `warp_execution_efficiency`, `dram_throughput_gbs`, `l2_hit_rate`, `tokens_per_sec` / `throughput_qps` when serving LLM / inference workloads.
  - Run order: correctness (`/cuda-correctness-audit` PASS) → occupancy sweep (block-size ∈ {64,128,256,512,1024}) → memory-layout ablation (AoS vs SoA, shared vs global, tensor-core vs FP32) → full benchmark at fixed problem size → roofline analysis.
  - Claim surface: throughput / occupancy at the declared compute capability — always disclose the arch (the `sm_XX` you set in `build.cuda_arch`). Audited by `/cuda-profile` and `/cuda-correctness-audit`.

Legacy alias `— domain: algorithms` (v2.2 early draft) is accepted and interpreted as `cpp-generic`.
