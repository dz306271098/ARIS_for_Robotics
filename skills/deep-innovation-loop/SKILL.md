---
name: deep-innovation-loop
description: "Autonomous deep research innovation loop for ML methods. Iteratively diagnoses root causes, researches literature for solutions, synthesizes novel method variants, tests them, and evolves the approach over 40+ rounds. Unlike auto-review-loop (symptom-fixing), this skill drives genuine methodological innovation with cumulative knowledge. Use when user says \"deep innovation\", \"evolve method\", \"deep loop\", \"innovate\", \"方法进化\", \"深度创新\", or wants autonomous method evolution beyond simple review-fix cycles."
argument-hint: [method-description-or-research-brief — baseline: <your_baseline>, venue: <target_venue>, domain: <your_domain>]
allowed-tools: Bash(*), Read, Write, Edit, Grep, Glob, WebSearch, WebFetch, Agent, Skill, Skill(codex:rescue), Skill(codex:adversarial-review)
---

# Deep Innovation Loop: Autonomous Method Evolution

Autonomously evolve a research method through iterative cycles of root-cause diagnosis, literature research, innovative design, implementation, evaluation, and reflection — for **$ARGUMENTS**.

This is NOT a review-fix loop. This is a **research program** that discovers, synthesizes, and validates novel techniques over 40+ rounds.

## Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Deep Innovation Loop                         │
│                                                                 │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   │
│  │ Phase A  │──▶│ Phase B  │──▶│ Phase C  │──▶│ Phase D  │   │
│  │ Diagnose │   │ Research │   │ Innovate │   │ Implement│   │
│  │ Root     │   │ Litera-  │   │ Design   │   │ & Eval   │   │
│  │ Cause    │   │ ture     │   │ Variants │   │          │   │
│  └──────────┘   └──────────┘   └──────────┘   └──────────┘   │
│       ▲                                             │          │
│       │         ┌──────────┐                        │          │
│       └─────────│ Phase E  │◀───────────────────────┘          │
│                 │ Reflect  │                                    │
│                 │ & Learn  │                                    │
│                 └──────────┘                                    │
│                                                                 │
│  Macro Phases:  EXPLORE (1-15) → REFINE (16-30) → POLISH (31+)│
└─────────────────────────────────────────────────────────────────┘
```

## Constants (override via $ARGUMENTS)

| Constant | Default | Description |
|----------|---------|-------------|
| `MAX_ROUNDS` | 50 | Hard upper limit on innovation rounds |
| `PHASE_EXPLORE` | 15 | Expected rounds 1-15: exploration-heavy (bold new techniques). Actual transition is driven by PATIENCE_EXPLORE, not hard round boundary. |
| `PHASE_REFINE` | 15 | Expected rounds 16-30: exploitation-heavy (optimize best variant). Actual transition is driven by PATIENCE_REFINE. |
| `PHASE_POLISH` | 10 | Expected rounds 31-40+: diminishing-returns optimization (ablation + robustness). Actual transition is driven by PATIENCE_POLISH. |
| `PATIENCE_EXPLORE` | 5 | No improvement for 5 rounds in explore → shift to refine |
| `PATIENCE_REFINE` | 4 | No improvement for 4 rounds in refine → shift to polish |
| `PATIENCE_POLISH` | 3 | No improvement for 3 rounds in polish → terminate |
| `REGRESSION_TOLERANCE` | 2 | Revert to best if 2 consecutive regressions |
| `TARGET_SCORE` | 8 | Primary stop condition (GPT-5.4 review score for target venue) |
| `LIT_SEARCH_COOLDOWN` | 3 | Min rounds between literature searches on same topic |
| `MAX_ACTIVE_VARIANTS` | 3 | Max variants proposed per round |
| `FUSION_INTERVAL` | 5 | Phase C Fusion rounds at rounds 5, 15, 25, 35, 45 (see precedence rule below) |
| `CROSS_DOMAIN_INTERVAL` | 7 | Phase B replacement at rounds 7, 14, 21, 28, 35, 42 — forced Cross-Domain Analogy pass (see `../shared-references/divergent-techniques.md` Operator 4). Converts reactive cross-domain into deliberate creative step. Phase B only — no collision with C/E. |
| `LEAP_ROUNDS` | {10, 20, 30} | Phase C rounds where cross-domain divergence is mandatory (see precedence rule below) |
| `TRAJECTORY_CHECKPOINTS` | {15, 30, 45} | Phase E Step 2.9 Trajectory Reanalysis fires at these macro boundaries (see `../shared-references/reframing-triggers.md`). Phase E only — no collision with C. |

### Round-Scheduling Precedence (resolves collisions at rounds 15, 30, 35)

Different phases can fire on the same round:

| Round | FUSION (Phase C) | LEAP (Phase C) | CROSS_DOMAIN (Phase B) | TRAJECTORY (Phase E) |
|-------|:----------------:|:--------------:|:----------------------:|:--------------------:|
| 10 | | ✓ | | |
| 14 | | | ✓ | |
| 15 | ✓ | | | ✓ |
| 20 | | ✓ | | |
| 21 | | | ✓ | |
| 25 | ✓ | | | |
| 28 | | | ✓ | |
| 30 | | ✓ | | ✓ |
| 35 | ✓ | | ✓ | |
| 42 | | | ✓ | |
| 45 | ✓ | | | ✓ |

**Precedence rules** (when multiple fire on one round):

1. **Phase B (`CROSS_DOMAIN_INTERVAL`)** is independent of Phase C/E — it only replaces Phase B's literature search. No collision possible with FUSION/LEAP/TRAJECTORY.

2. **Phase C FUSION vs LEAP**: LEAP rounds {10,20,30} override FUSION rounds. On round 30, LEAP executes (not FUSION). Rationale: LEAP provides lateral creative jumps that a stagnant loop needs more than combinatorial optimization. FUSION rounds are 5/15/25/35/45 — the five rounds where `round % 5 == 0` AND round is NOT in LEAP_ROUNDS.

3. **Phase E TRAJECTORY** always runs independently of Phase C outcome. On round 15 (FUSION + TRAJECTORY): Phase C runs as FUSION, then Phase E Step 2.9 TRAJECTORY runs on top of the FUSION results. On round 30 (LEAP + TRAJECTORY): Phase C runs as LEAP, Phase E TRAJECTORY runs. On round 45 (FUSION + TRAJECTORY): both run sequentially.

4. **Round 35**: CROSS_DOMAIN (Phase B) + FUSION (Phase C) both fire — both run (Phase B replaces literature search, Phase C runs FUSION). No conflict.

Summary: there are no true conflicts because collisions are across different phases. The precedence rules above resolve only the within-Phase-C ambiguity (FUSION vs LEAP on their overlap round 30 — resolved: LEAP wins).
| `REVIEWER_MODEL` | gpt-5.4 | External reviewer model via Codex CLI |
| `HUMAN_CHECKPOINT` | false | When true, pause after each round's diagnosis for user input |
| `COMPACT` | false | When true, use compact logs for session recovery |
| `VENUE` | RAL | Target venue (IEEE Robotics and Automation Letters) |
| `DOMAIN` | robotics | Research domain (override for your specific sub-domain, e.g., manipulation, navigation, locomotion) |
| `PRIMARY_BASELINE` | "" | **REQUIRED.** Primary comparison baseline (e.g., PointNet++, RRT*, DAgger, SLAM baseline). If empty at startup, halt and ask user. |

**Startup check:** If `PRIMARY_BASELINE` is empty and cannot be inferred from `CLAUDE.md` or `EXPERIMENT_PLAN.md`, halt immediately and ask the user to specify a baseline. Do NOT proceed with an empty baseline.

Override inline: `/deep-innovation-loop "improve robot manipulation" — baseline: DAgger, venue: CoRL, domain: manipulation, max rounds: 40, human checkpoint: true`

## Full Autonomy Principle

This loop is designed to run **fully autonomously for 40+ rounds without human intervention**. At every decision point:

1. **Never block** — make the best decision based on available data, document reasoning, continue.
2. **Auto-select variants** — after GPT-5.4 adversarial challenge, Claude Opus 4.6 selects the surviving variant with the best expected improvement. No user approval needed.
3. **Auto-recover** — experiment failure → auto-debug (3 attempts) → revert to best variant if unrecoverable → continue loop.
4. **Auto-pivot** — if the current direction plateaus (patience exhausted), automatically transition to the next macro phase. No user confirmation.
5. **Auto-infer** — if required files are missing, infer from context. Never stop to ask.
6. **Log all decisions** — every autonomous choice is logged with `[AUTO-DECISION]` prefix and reasoning, so the user can review the full decision trail in `EVOLUTION_LOG.md` after the loop completes.

The only exception: `HUMAN_CHECKPOINT=true` explicitly opts into manual review (off by default).

## Output File Structure

```
innovation-logs/
├── INNOVATION_STATE.json           # State machine (for session recovery)
├── TECHNIQUE_LIBRARY.md            # Cumulative knowledge base (grows across rounds)
├── EVOLUTION_LOG.md                # Method morphing history (full lineage tree)
├── INNOVATION_REVIEW.md            # Cumulative review log
├── BLACKLIST.md                    # Approaches proven ineffective (with reasons)
├── FUSION_CANDIDATES.md            # Synergy combinations to test
├── findings.md                     # Key research + engineering findings
├── score-history.csv               # Metric progression (primary_metric, secondary_metric, task_metric, etc.)
├── round-NN/                       # Per-round detailed records
│   ├── diagnosis.md                #   Root cause analysis
│   ├── research.md                 #   Literature search results
│   ├── innovation.md               #   Proposed method variants
│   ├── results.md                  #   Experiment results
│   └── reflection.md               #   Reflection and decisions
└── FINAL_METHOD.md                 # Best method description at termination
```

## State Persistence (Session Recovery)

Write `INNOVATION_STATE.json` after each Phase E:

```json
{
  "round": 12,
  "macro_phase": "explore",
  "threadId": "019cd392-...",
  "status": "in_progress",
  "best_score": 6.5,
  "best_round": 9,
  "best_variant": "v9-adaptive-ekf-transformer",
  "current_variant": "v12-spatial-attention-grasp",
  "patience_counter": 2,
  "regression_counter": 0,
  "explored_techniques": ["spatial_attention", "force_feedback", "policy_distillation"],
  "failed_approaches": ["raw_lstm:no_physics_awareness", "naive_transformer:drift_accumulation"],
  "baseline_metrics": {"success_rate": 0.72, "completion_time": 15.3},
  "best_metrics": {"success_rate": 0.89, "completion_time": 11.2},
  "pending_experiments": ["screen_exp_v12"],
  "metrics_history": [
    {"round": 0, "variant": "baseline-DAgger", "success_rate": 0.72, "completion_time": 15.3, "score": 4.0}
  ],
  "timestamp": "2026-03-31T21:00:00"
}
```

**Recovery logic:**
- `INNOVATION_STATE.json` does NOT exist → **fresh start**
- exists AND `status = "completed"` → **fresh start** (previous loop finished)
- exists AND `status = "in_progress"` AND `timestamp > 24 hours old` → **fresh start** (stale, delete file)
- exists AND `status = "in_progress"` AND `timestamp within 24 hours` → **RESUME**
  - Recover `round`, `threadId`, `best_score`, `best_variant`, `patience_counter`, `macro_phase`
  - Read `EVOLUTION_LOG.md` and `TECHNIQUE_LIBRARY.md` to restore context
  - Check if pending experiments completed
  - Resume from next round (round = saved round + 1)

## Execution Rule

Follow the phases in order. Do **not** stop unless a stopping condition is met. Work AUTONOMOUSLY — do not ask user for permission at each round unless `HUMAN_CHECKPOINT=true`.

## Initialization

1. **Check for recovery**: Read `innovation-logs/INNOVATION_STATE.json`. Apply recovery logic above.

2. **Read project context**: Load `RESEARCH_BRIEF.md` or `CLAUDE.md` for problem context. Read existing codebase to understand current method implementation.

3. **Freeze the Research Anchor** (immutable throughout the loop):

   ```markdown
   ## Research Anchor
   - **Target venue**: [VENUE]
   - **Primary baseline**: [PRIMARY_BASELINE]
   - **Domain**: [DOMAIN]
   - **Must-beat metrics**: [from CLAUDE.md or RESEARCH_BRIEF.md]
   - **Hardware constraints**: [from CLAUDE.md — GPU type, count, time budget]
   - **Non-goals**: [explicitly excluded directions]
   ```

   The Research Anchor is checked every round. If the method drifts away from the anchor, Phase E forces a correction.

4. **Run baseline evaluation**: Run `PRIMARY_BASELINE` on the standard benchmark sequences. Record as Round 0 in `score-history.csv`.

5. **Initialize knowledge files**:
   - `TECHNIQUE_LIBRARY.md` — seed with techniques from the current method
   - `EVOLUTION_LOG.md` — Round 0 = baseline description
   - `BLACKLIST.md` — empty
   - `FUSION_CANDIDATES.md` — empty
   - `score-history.csv` — header + Round 0 row

## Per-Round Pipeline (Phases A → E)

Repeat until a stopping condition is met.

---

### Phase A: Deep Diagnosis (Root Cause Analysis)

**Goal**: Identify WHY the method fails, not just WHERE. Trace symptoms to mathematical, physical, or architectural root causes.

This is the critical differentiator from `auto-review-loop`. Instead of asking "what's wrong," ask "**why** is it wrong."

**Step 0.5: Hypothesis Sparring (MANDATORY every round)** — see `../shared-references/hypothesis-sparring.md`.

Before committing to any single root cause, generate **≥3 competing mechanistic hypotheses with probability weights in (0, 0.6) summing to 1.0**, and for each specify the cheapest falsifier. Run the cheapest-ranked falsifier first; update weights; proceed only when one hypothesis has weight ≥ 0.8 OR falsifier budget exhausted (2 falsifiers max).

```
/codex:rescue --effort xhigh "
Apply shared-references/hypothesis-sparring.md to the current failure pattern.

Read:
- innovation-logs/round-{N-1}/results.md
- innovation-logs/score-history.csv (last 5 rounds)
- src/ (relevant modules to reason about failure modes)

Produce the hypothesis sparring table (≥3 competing hypotheses with weights, predicted evidence, cheapest falsifiers ranked by information-gain / cost).
Run the #1-ranked falsifier only. Report the result and update weights. Do NOT design fixes.
"
```

Save to `innovation-logs/round-NN/hypothesis-sparring.md`. The surviving hypothesis becomes the working root cause for the rest of Phase A.

**Collaborative Root-Cause Reanalysis** (see `../shared-references/collaborative-protocol.md`):

If `patience_counter >= 3` (no improvement for 3+ rounds), the current diagnosis may be WRONG. Before running the normal Phase A, trigger:

**Step 0: Independent diagnosis from raw files** (Codex Plugin — GPT-5.4 reads everything directly):
```
/codex:rescue --effort xhigh "We've been stuck for {patience_counter} rounds with no improvement. Read the last 3 rounds of results in innovation-logs/, the TECHNIQUE_LIBRARY.md, score-history.csv, and EVOLUTION_LOG.md. Independently diagnose why we're stuck. Don't trust any prior summaries — read the raw files and form your own assessment."
```

Append rescue findings to the collaborative context below.

**Step 1: Collaborative reanalysis** (Codex CLI dialogue — multi-turn, with rescue findings as input):
```
/codex:rescue --effort xhigh "
[COLLABORATIVE MODE — Joint Root-Cause Reanalysis]

Read these files directly:
- innovation-logs/score-history.csv — full metrics history
- innovation-logs/EVOLUTION_LOG.md — last 5+ entries with decisions
- innovation-logs/TECHNIQUE_LIBRARY.md — all tested techniques
- innovation-logs/round-{N-1}/results.md, round-{N-2}/results.md, round-{N-3}/results.md
- src/ — current model source code

We've been stuck for {patience_counter} rounds with no improvement.

Previous diagnosis: [root cause from last Phase A]
What was tried: [list of attempted variants and results]

The diagnosis may be wrong, or the root cause may have shifted.
    
    1. Given my implementation evidence, do you still believe [root cause] is correct?
    2. What alternative root causes could explain the persistent plateau?
    3. Is there a deeper structural issue we're both missing?
    
    Let's re-diagnose together before spending more rounds on the wrong problem.
```

Claude responds with code/data evidence → GPT revises analysis → up to 4 turns. If a NEW root cause is identified, update the diagnosis and proceed to Phase B/C with the revised understanding. If the diagnosis holds, proceed normally but with a broader search strategy (more cross-domain literature in Phase B).

Log to `innovation-logs/round-NN/collaborative-reanalysis.md`.

Always use `--effort xhigh` for maximum reasoning depth.

**Phase A.5: Assumption Attack (conditional — fires whenever diagnosis converges)** — see `../shared-references/reframing-triggers.md` Trigger 1.

A convergent diagnosis is the danger zone: the loop is about to commit significant compute to fixing what may be a narrowly-correct-but-hiding-a-wrong-assumption diagnosis. Run Assumption Attack once before proceeding.

**Fires when ANY of the following produce a convergent single root cause** (not doubly-conditional — fires in early rounds too):
1. The Every-Round Phase A rescue call below produces a single-cause diagnosis (the common path, applies from Round 1 onward)
2. Collaborative Reanalysis Step 1 (patience_counter ≥ 3) converges — the stuck-round path
3. Step 0.5 Hypothesis Sparring converges on a surviving hypothesis with weight ≥ 0.8

**Skip only when** the diagnosis is explicitly multi-cause (≥ 2 contributing root causes without one dominating). Multi-cause diagnoses are self-protective against the comfortable-convergence failure mode that Assumption Attack targets.

**GATE (non-skippable when fired)**: before Phase B/C proceeds, verify Assumption Attack ran if convergence was detected:
```bash
if [ "$PHASE_A_CONVERGED" = "true" ]; then
    test -f "innovation-logs/round-$N/assumption-attack.md" || { echo "HALT: Assumption Attack required after convergent diagnosis but output missing"; exit 1; }
fi
```

```
/codex:rescue --effort xhigh "
Apply shared-references/reframing-triggers.md Trigger 1 (Assumption Attack).

Converged diagnosis: [the root cause the collaborative reanalysis agreed on]

1. Parse the diagnosis — for each noun and verb, write the hidden assumption it encodes.
2. Rank assumptions by fragility (1 clearly true, 5 clearly questionable). At least one must be rated ≥ 3.
3. For the most fragile assumption, write the inverted hypothesis.
4. Evidence check: does any existing evidence (logs, prior runs, ablations) look more consistent with inversion than with the diagnosis?
5. Decision: proceed with original diagnosis, OR fork the inversion into Phase C as a competing variant design, OR replace the diagnosis if evidence clearly favors the inversion.
"
```

Save to `innovation-logs/round-NN/assumption-attack.md`. If the decision is "fork inversion," add the inversion as a required additional variant in Phase C.

---

**Phase A execution enforcement** (see `../shared-references/codex-context-integrity.md` "Execution Enforcement Gates"):

Before Phase B / C proceeds, verify the required Phase A artifacts exist for this round:

```bash
test -f "innovation-logs/round-$N/hypothesis-sparring.md" || { echo "HALT: Step 0.5 hypothesis sparring missing"; exit 1; }
test -f "innovation-logs/round-$N/diagnosis.md" || { echo "HALT: Root cause diagnosis missing"; exit 1; }

# If convergence triggered Phase A.5, assumption attack is also required:
if [ "$PHASE_A_CONVERGED" = "true" ]; then
    test -f "innovation-logs/round-$N/assumption-attack.md" || { echo "HALT: Assumption Attack required after convergent diagnosis"; exit 1; }
fi

# If patience_counter >= 3 triggered Step 1 collaborative reanalysis, that file is also required:
if [ "$PATIENCE_COUNTER" -ge 3 ]; then
    test -f "innovation-logs/round-$N/collaborative-reanalysis.md" || { echo "HALT: Collaborative reanalysis required when patience_counter >= 3"; exit 1; }
fi
```

**Every round** — use a fresh `/codex:rescue` call (GPT-5.4 reads latest files directly; context accumulates in innovation-logs/ which GPT-5.4 reads):

```
/codex:rescue --effort xhigh "
  prompt: |
    [Round N/MAX_ROUNDS — ROOT CAUSE DIAGNOSIS]
    
    FILES TO READ (read these files directly from the project directory):
    - innovation-logs/score-history.csv — full metrics progression
    - innovation-logs/TECHNIQUE_LIBRARY.md — all explored techniques + distilled principles
    - innovation-logs/BLACKLIST.md — failed approaches (do NOT suggest)
    - innovation-logs/EVOLUTION_LOG.md — method evolution history (last 5 entries)
    - innovation-logs/round-{N-1}/results.md — last round's detailed results
    - innovation-logs/INNOVATION_STATE.json — current state (best score, phase, patience)
    - src/ — current model source code (read key modules)
    
    Read these files yourself to form your own diagnosis.
    Do NOT rely solely on the context I provide below.
    
    Domain: [DOMAIN]
    Target venue: [VENUE]
    Primary baseline: [PRIMARY_BASELINE]
    
    Current method (v{N-1}): [complete method description]
    
    Latest results (inline backup — verify against files above):
    [full metrics table — per-sequence breakdown]
    
    Results trend (last 5 rounds):
    [metrics progression showing improvement/regression per round]
    
    BLACKLISTED approaches — do NOT suggest these:
    [paste from BLACKLIST.md]
    
    Known effective techniques — build on these:
    [paste relevant entries from TECHNIQUE_LIBRARY.md with status TESTED-POSITIVE]
    
    TASK: Perform deep ROOT CAUSE analysis. Do NOT list surface symptoms.
    
    For EACH weakness in the current method:
    1. SYMPTOM: Which metric is bad and on which sequences/scenarios?
    2. ROOT CAUSE: WHY does this happen? Trace to the underlying 
       mathematical/physical/architectural reason.
       (e.g., "drift accumulates because the network has no mechanism 
       to observe absolute orientation — it only sees relative rotations, 
       so the error is unobservable")
    3. CAUSAL CHAIN: Symptom ← Intermediate cause ← Root cause
    4. ANALOGIES: Has this root cause been solved in adjacent fields?
       (manipulation, navigation, SLAM, perception, planning, 
       control theory, sensor fusion, sim-to-real)
    5. DIFFICULTY: Architecture change / loss function / training strategy / 
       data augmentation / post-processing / hyperparameter tuning
    6. INNOVATION DIRECTIONS: Based on the root cause, propose 2-3 
       promising technical directions for a novel solution.
    
    Score the current method 1-10 for [VENUE] submission quality.
    Focus on: technical depth, experimental rigor, novelty vs [PRIMARY_BASELINE],
    generalization across sequences, and whether the contribution is 
    significant enough for [VENUE].
```

**CRITICAL**: Save the FULL raw response verbatim. Save `threadId` from the response.

Save to `innovation-logs/round-NN/diagnosis.md`.

---

### Phase B: Targeted Literature Research (Conditional) + Forced Cross-Domain Analogy

**Goal**: Find techniques from the literature that address newly identified root causes. On designated rounds, forcibly replace regular literature search with a proactive cross-domain analogy pass.

**Proactive Cross-Domain Analogy Rounds** — fires on `round % CROSS_DOMAIN_INTERVAL == 0` (rounds 7, 14, 21, 28, 35, 42). These rounds **replace** regular Phase B with a deliberate analogical search, regardless of whether Phase A produced a new root cause.

On a Cross-Domain round:

```
/codex:rescue --effort xhigh "
Apply shared-references/divergent-techniques.md Operator 4 (Cross-Domain Leap).

Read:
- innovation-logs/TECHNIQUE_LIBRARY.md — current best variant's principle set
- innovation-logs/IDEA_DIVERGENCE_LOG.md (if exists) — previously-used source domains

Source domain for this round: [DOMAIN — pick one from the Operator 4 rotating pool that has NOT been used in the last 3 entries of IDEA_DIVERGENCE_LOG. Priority to most distant: physics, biology, economics, signal processing, linguistics, materials science, neuroscience, games, ecology, music.]

Steps:
1. Abstract our current best variant's problem structure in 2 sentences using domain-neutral vocabulary.
2. Find an analogous phenomenon in [DOMAIN]. Name it in [DOMAIN]'s native vocabulary.
3. Identify the principle that makes the [DOMAIN] solution effective — one domain-agnostic sentence (cite principle-extraction.md Layer 3).
4. Translate the principle into our problem's vocabulary. Re-derive a realization from scratch.
5. Explicitly state what from [DOMAIN] we are NOT importing (Anti-Copying Guard).
6. Produce one concrete UNTESTED technique entry for TECHNIQUE_LIBRARY.md, tagged `cross-domain-analogy`, with source domain logged.

Append [DOMAIN] to IDEA_DIVERGENCE_LOG.md.
"
```

Add the output to `TECHNIQUE_LIBRARY.md` as UNTESTED with tag `cross-domain-analogy`. This becomes a candidate for Phase C variants in subsequent rounds.

**Regular Phase B trigger conditions** (on non-Cross-Domain rounds, Phase B is NOT executed every round — it triggers only when):
- Phase A identified a root cause NOT already covered in `TECHNIQUE_LIBRARY.md`
- At least `LIT_SEARCH_COOLDOWN` rounds have passed since last search on the same topic
- Phase A identified a promising analogy to another field

**If none of these conditions are met AND this is not a Cross-Domain round**: Skip Phase B, proceed directly to Phase C using existing knowledge from `TECHNIQUE_LIBRARY.md`.

**For each new root cause requiring research:**

1. **Check existing knowledge**: Search `TECHNIQUE_LIBRARY.md` for techniques addressing this root cause.
   - If found with status `TESTED-POSITIVE`: use directly, skip search.
   - If found with status `TESTED-NEGATIVE`: note what failed and why, search for alternatives.
   - If not found: proceed to search.

2. **Multi-source literature search** (with web resilience — see rules below):

   **IMPORTANT: Use API tools as primary, WebSearch as fallback. Never let a web operation block the pipeline.**

   a. **arXiv search** — PREFER the API tool over WebSearch:
      ```bash
      # Primary: reliable API tool with built-in timeout
      python tools/arxiv_fetch.py search "robot manipulation force control"
      ```
      - Keywords: combine domain terms + root cause concept
      - Example: `"robot grasping" AND "force control"`, 
        `"motion planning" AND "collision avoidance"`, `"policy learning" AND "attention"`
      - Focus on last 2 years, categories: cs.RO, cs.AI, cs.LG
      - Only use WebSearch as fallback if the API tool fails
   
   b. **Semantic Scholar** — PREFER the API tool over WebSearch:
      ```bash
      # Primary: reliable API tool with built-in timeout
      python tools/semantic_scholar_fetch.py search "robot learning" --year 2024-2026
      ```
      - Target venues: RAL, ICRA, IROS, TRO, CoRL, RSS
      - Also check adjacent: IEEE TSP, ICASSP, NeurIPS, ICML (for method innovations)
      - Filter by citation count and recency
   
   c. **Adjacent domain search** (WebSearch acceptable here, with timeout):
      - If root cause is "sim-to-real gap" → search domain adaptation / transfer learning
      - If root cause is "sensor noise" → search signal processing / sensor fusion
      - If root cause is "temporal modeling" → search sequence modeling / transformers
      - If root cause is "physics mismatch" → search physics-informed neural networks
      - **If WebSearch hangs (~60s), abandon and skip** — adjacent domain search is supplementary, not critical

   **Web Resilience**: If ANY web operation hangs, abandon it immediately and continue with already-collected results. Phase B must NEVER block the pipeline. If all searches fail, proceed to Phase C using existing `TECHNIQUE_LIBRARY.md` knowledge and note `[WEB SEARCH UNAVAILABLE]` in the round's research log.

3. **Extract, distill, and catalog**: For each relevant technique found, first apply the Principle Extraction Protocol from `../shared-references/principle-extraction.md`, then catalog:

   ```markdown
   ## [Technique Name] — [Source Field]
   
   - **Paper**: [full citation]
   - **Root cause addressed**: [which root cause from Phase A this solves]
   - **Mechanism**: [1-2 sentence technical description]
   - **Mathematical formulation**: [key equations if applicable]
   - **Reported improvement**: [quantitative, with dataset/benchmark caveats]
   - **Distilled principle**: [1-2 sentences — WHY this works, abstracted from all implementation details. No paper-specific nouns. Must pass the one-sentence test from principle-extraction.md]
   - **Generalized form**: [domain-agnostic formulation of the principle]
   - **Adaptation for our problem**: [how this principle applies to our specific research context]
   - **DO NOT copy**: [specific elements from this paper to avoid transplanting]
   - **Integration cost**: LOW (config/loss change) / MEDIUM (new module) / HIGH (architecture change)
   - **Compatibility with current architecture**: [specific notes]
   - **Status**: UNTESTED
   - **Tested in round(s)**: []
   - **Synergy potential**: [which other techniques/principles it could combine with, and why]
   ```

4. **Add to `TECHNIQUE_LIBRARY.md`**. De-duplicate: if a technique is already in the library, update its entry with new information.

Save search results to `innovation-logs/round-NN/research.md`.

---

### Phase C: Innovation Design (The Creative Core)

**Goal**: Design method variants that elegantly fuse techniques to address root causes, achieving "1+1>2" synergy.

**Strategy selection based on macro phase:**

| Macro Phase | Primary Strategy | Secondary Strategy |
|-------------|-----------------|-------------------|
| **Explore** (rounds 1–PHASE_EXPLORE) | Cross-pollination: combine techniques from different fields | Novel variants: adapt existing techniques for the domain |
| **Refine** (rounds PHASE_EXPLORE+1 to PHASE_EXPLORE+PHASE_REFINE) | Fusion optimization: systematically test technique combinations | Hyperparameter + architecture tuning of best variant |
| **Polish** (rounds beyond PHASE_EXPLORE+PHASE_REFINE) | Ablation-guided trimming: remove unnecessary complexity | Edge case handling and robustness improvements |

**Special case — Leap Round** (triggered when `round in LEAP_ROUNDS = {10, 20, 30}`):

Replace normal Phase C with a forced cross-domain divergence pass. This complements Fusion rounds (5/15/25) by ensuring the loop gets three guaranteed lateral-thinking injections per 50-round run.

```
/codex:rescue --effort xhigh "
Apply shared-references/divergent-techniques.md Operator 4 (Cross-Domain Leap) AND Operator 1 (SCAMPER) to the current best variant.

Read:
- innovation-logs/TECHNIQUE_LIBRARY.md — cumulative principles (especially cross-domain-analogy tagged entries)
- innovation-logs/BLACKLIST.md — do NOT propose anything similar
- innovation-logs/IDEA_DIVERGENCE_LOG.md — previously-used source domains (rotate)
- src/ — current best variant implementation

Step 1 — Cross-Domain Leap: sample ONE source domain not used in last 3 log entries. Produce 1 concrete variant that embodies a [DOMAIN] principle re-specialized for our problem.

Step 2 — SCAMPER: apply 2 of the 7 operators (Substitute, Combine, Adapt, Modify, Put-to-other-use, Eliminate, Reverse) to the current best variant. Produce 2 structurally different variants.

Output: 3 candidate variants (1 cross-domain + 2 SCAMPER). Each tagged with the operator that produced it. Each must pass the adversarial challenge in the same round.

Log the source domain to IDEA_DIVERGENCE_LOG.md.
"
```

Leap rounds share Phase C's adversarial challenge (devil's advocate) — weak variants are still killed before implementation.

**Special case — Fusion Round** (triggered when `round % FUSION_INTERVAL == 0`, e.g., rounds 5, 15, 25, note: rounds 10/20/30 are LEAP not FUSION):

Replace normal Phase C with a fusion-specific round:

1. Read `TECHNIQUE_LIBRARY.md` — identify all `TESTED-POSITIVE` and `TESTED-MIXED` techniques
2. Read `FUSION_CANDIDATES.md` for pre-identified synergy pairs
3. For each candidate combination:
   - Does technique A's strength compensate for technique B's weakness?
   - Are they architecturally compatible (no conflicting assumptions)?
   - Has this exact combination been tested before?
4. Submit fusion candidates to GPT-5.4 for ranking via `/codex:rescue`:
   ```
   prompt: |
     [Round N — FUSION OPTIMIZATION]
     
     These techniques have been individually tested. Rank the following 
     fusion combinations by expected synergy, considering architectural 
     compatibility and complementary strengths:
     [paste candidate combinations with individual test results]
     
     For each combination: expected improvement, risk, implementation plan.
     Rank top 3.
   ```
5. Claude Opus 4.6 (executor) selects and tests the top 1-2 fusion combinations based on GPT-5.4's ranking and available compute

**Normal round — Innovation proposal via Codex Plugin:**

```
/codex:rescue --effort xhigh "
[Round N — INNOVATION DESIGN]

Read these files directly:
- innovation-logs/TECHNIQUE_LIBRARY.md — all techniques + distilled principles
- innovation-logs/BLACKLIST.md — banned approaches (do NOT propose anything similar)
- innovation-logs/EVOLUTION_LOG.md — last 5 entries (method lineage)
- innovation-logs/FUSION_CANDIDATES.md — potential technique combinations
- src/ — current model source code (read key modules to understand implementation)

Focus on 'Distilled principle', 'Generalized form', and 'Adaptation for our problem' 
fields in TECHNIQUE_LIBRARY.md. Design variants from PRINCIPLES, not surface methods.

Root causes from diagnosis:
[paste key findings from Phase A]

Current best method (v{best_round}, score {best_score}/10):
[complete description]

Current method (v{N-1}) if different from best:
    [description and how it differs]
    
    Macro phase: {explore/refine/polish}
    Research Anchor: [paste frozen anchor]
    
    TASK: Propose 2-3 method variants that address the identified root causes.
    
    For EACH variant:
    1. NAME: descriptive variant name (e.g., "v12-spatial-attention-grasp")
    2. HYPOTHESIS: What specific improvement do you expect and why?
    3. MECHANISM: Exactly what changes from current best method
    4. TECHNIQUE FUSION: Which techniques from the library are combined?
    5. WHY 1+1>2: Why does combining these techniques create synergy?
    5.5. PRINCIPLE GROUNDING: Which distilled principle(s) from the library 
         inspired this variant? State the principle, not the paper's method.
         Verify: does this variant's design look different from the source 
         paper's implementation while embodying the same principle?
       (e.g., "Technique A provides spatial attention features, which makes 
       Technique B's policy network focus on task-relevant regions 
       instead of background clutter, amplifying both effects")
    6. IMPLEMENTATION: Concrete code changes needed (files, functions, modules)
    7. RISK: What could go wrong? What assumptions might be violated?
    8. EXPECTED METRIC IMPACT: Which metrics improve? Which might regress?
    9. ESTIMATED EFFORT: Hours to implement
    
    CONSTRAINTS:
    - Do NOT propose anything on the BLACKLIST
    - Each variant MUST differ from current best by at most 1-2 components
      (too many changes = cannot attribute improvement)
    - {explore phase}: Prefer novel combinations and cross-domain techniques
    - {refine phase}: Prefer refinements of the best-performing variant
    - {polish phase}: Prefer simplifications and robustness improvements
    - Every variant must be testable with available compute
    - Prefer techniques with UNTESTED status in the library
```

**Pre-Adversarial Failure-Library Check** (NEW, runs before Adversarial Challenge):

For each variant proposed, query the wiki failure library to surface known failure patterns BEFORE the adversarial challenge. This lets the adversarial prompt reference specific documented failures rather than only speculating.

```
If research-wiki/ exists:
  For each variant in innovation-logs/round-NN/innovation.md:
    1. Extract the principles it embodies (from the PRINCIPLE GROUNDING field — Phase 1 of this skill already requires this).
    2. For each principle, query research-wiki/failures/ for failure patterns with failure_mode_of edges to that principle.
    3. Detect OVERLAP: do any failure patterns afflict ≥ 2 of the variant's principles simultaneously? Co-occurring failures indicate the variant sits in a known failure cluster.
    4. Check research-wiki/AUDIT_REPORT.md analysis (d) for Unresolved failures + failure-clusters that match.
    5. Produce variant_failure_context.md per variant with: | principle | known failures (slug) | status | applies? | resolutions if any |
```

Append `variant_failure_context.md` (one per variant) to the adversarial prompt below, so the adversarial reviewer has specific failures to reference. If the library has no relevant failures, note "no library coverage for this variant's principles" in the prompt.

**Adversarial Challenge** (GPT-5.4 plays devil's advocate on the proposed variants — now informed by failure library):

After the failure-library check, immediately challenge the variants:

```
/codex:rescue --effort xhigh "
[Round N — ADVERSARIAL CHALLENGE]

Read the variant proposals in innovation-logs/round-NN/innovation.md.
Read the failure context in innovation-logs/round-NN/variant_failure_context_*.md (if produced).
Also read src/ to understand the current codebase.

Play DEVIL'S ADVOCATE on the proposed variants.
    For EACH variant:
    
    1. FATAL FLAW: What is the single strongest reason this will NOT work?
    2. HIDDEN ASSUMPTION: What assumption are you making that might be wrong?
    3. EASIER ALTERNATIVE: Is there a simpler approach that achieves the 
       same goal without this complexity?
    4. EVALUATION TRAP: How could this variant appear to improve metrics 
       but actually be a flawed improvement (e.g., overfitting, unfair 
       comparison, metric gaming)?
    5. KNOWN FAILURE CHECK (if variant_failure_context present): for each 
       failure pattern in the context that applies to this variant, does 
       the variant have a specific mechanism that breaks the failure trigger, 
       or does it just hope the failure won't manifest? Hope is not a mechanism.
       Failed pattern addressing ⇒ FATAL FLAW unless the variant names a 
       concrete failure-breaking mechanism.
    6. SURVIVAL VERDICT: After your own critique, which variant(s) survive?
       Kill any variant whose fatal flaw is unresolvable.
    
    Be BRUTALLY honest. The purpose is to eliminate weak ideas BEFORE 
    wasting GPU hours on them.
```

**Variant selection** (by Claude Opus 4.6 — the executor makes the final decision, informed by GPT-5.4's adversarial feedback):

Only select from variants that **survived** GPT-5.4's adversarial challenge (i.e., NOT killed by a fatal flaw). Claude Opus 4.6 applies these selection criteria:
1. Does it address the highest-severity root cause?
2. Did it survive GPT-5.4's adversarial critique without a fatal flaw?
3. Is the hypothesis testable with available resources?
4. Does it build on the current best variant, not a dead branch?
5. Is the change small enough to attribute improvement?
6. Does the synergy argument ("1+1>2") make physical/mathematical sense?

If GPT-5.4 killed all variants: request new proposals in the same thread, incorporating the critique.

**Collaborative Variant Design** (escalation — see `../shared-references/collaborative-protocol.md`):

If adversarial challenge kills ALL proposed variants for **2 consecutive rounds**, switch from adversarial to collaborative mode:

```
/codex:rescue --effort xhigh "
[COLLABORATIVE MODE — Joint Variant Design]

Read these files directly:
- innovation-logs/EVOLUTION_LOG.md — full history of killed variants and why
- innovation-logs/TECHNIQUE_LIBRARY.md — available techniques
- innovation-logs/BLACKLIST.md — banned approaches
- src/ — current codebase and constraints

We've hit a wall. All variants killed for 2 consecutive rounds.
    
    Your recurring objections: [list the main flaws cited across killed variants]
    My implementation evidence: [what Claude observed trying to implement past variants]
    Practical constraints: [what's actually feasible given codebase, data, compute]
    
    Let's design something together instead of the propose-kill cycle.
    
    1. What theoretical property MUST the solution have to avoid your objections?
    2. Given my implementation constraints, what form could that take?
    3. Propose a variant that satisfies BOTH your theoretical concerns 
       and my practical constraints.
```

Then Claude responds with feasibility feedback → GPT refines → up to 6 turns total (see collaborative-protocol.md). The jointly-designed variant proceeds to Phase D implementation, then **returns to adversarial mode** for validation — GPT reviews the implementation as usual.

Log the full collaborative session to `innovation-logs/round-NN/collaborative-design.md`.

**Anti-circle check**: Before implementing, compare the selected variant against the last 5 variants in `EVOLUTION_LOG.md`. If the proposed change is essentially identical to a previously tried variant (same technique combination, same integration point), reject it and request a different proposal.

Save to `innovation-logs/round-NN/innovation.md` (include both proposals AND adversarial critique).

---

### Phase D: Implementation and Evaluation

**Goal**: Implement the selected variant, run experiments, and compare against baseline + current best.

**Step 1: Implement**
- Make the code changes described in the selected variant
- Self-review: does the implementation match the design?
- Code quality: proper seeding, logging, result saving

**Step 1.1: Mandatory Code Review** (every round, after ANY code change):

After implementing the variant, ALWAYS run an adversarial review:
```
/codex:adversarial-review --scope working-tree --focus "Review variant implementation for: correctness vs design spec, logic bugs, fair baseline comparison, proper seeding, evaluation metric accuracy"
```
- If verdict = `approve` → proceed to Step 1.5
- If verdict = `needs-attention` → apply **Review Feedback Verification Protocol** (see `../shared-references/codex-context-integrity.md`):
  - Evaluate each finding for correctness
  - Agreed findings → fix
  - Disputed findings → submit rebuttal via `/codex:rescue` for adjudication
  - After disputes resolved, fix all confirmed issues → re-run adversarial-review
- **This step is NOT skippable** — every code change must pass adversarial review before deployment

**Step 1.2: Post-Coding Verification**

After adversarial review passes, run the **Post-Coding Verification Protocol** (`../shared-references/post-coding-verification.md`). All 3 layers (module test → integration test → regression check) must pass before proceeding. If any fails, fix and re-run Step 1.1 + 1.2. Log results to `EVOLUTION_LOG.md`.

**Step 1.5: Experiment Design + Code Review (Dual Channel)**

Before deploying, run BOTH an independent file-based audit AND a dialogue-based design review:

**Step 1.5a: Independent Code Audit** (Codex Plugin — GPT-5.4 reads actual code diff):
```
/codex:adversarial-review --base HEAD~1 --focus "Verify this variant implements the stated hypothesis correctly, baseline comparison is fair (same tuning budget, same data, same compute), no logic bugs, evaluation uses ground truth not model output, seeds are fixed"
```

If adversarial-review returns `needs-attention`: apply **Review Feedback Verification Protocol** (see `../shared-references/codex-context-integrity.md`) — evaluate each finding for correctness, dispute incorrect ones via `/codex:rescue`. Confirmed CRITICAL issues must be fixed and re-reviewed.

**Step 1.5b: Design Review** (Codex Plugin — reads code directly):

Submit the experiment design for review via rescue:

```
/codex:rescue --effort xhigh "
[Round N — EXPERIMENT DESIGN & CODE REVIEW]

Read these files directly:
- src/ — all modified source code for this variant
- innovation-logs/round-NN/innovation.md — variant design spec
- git diff HEAD~1 — exact code changes

Variant: [name and description]
    Hypothesis: [what we expect to see]
    
    Experiment setup:
    - Dataset/sequences: [list]
    - Metrics: [list]
    - Baselines: [list]
    - Training config: [key hyperparameters]
    - Evaluation protocol: [how results are compared]
    
    Key code changes:
    [paste the diff or key modified functions]
    
    REVIEW CHECKLIST:
    1. Does the experiment actually test the stated hypothesis?
    2. Is the comparison against baselines fair (same data, same budget)?
    3. Are there logic bugs in the implementation?
    4. CRITICAL: Does evaluation use dataset ground truth, NOT another 
       model's output?
    5. Could the result be trivially explained by something other than 
       the proposed innovation (e.g., more parameters, more data, lucky seed)?
    6. Are seeds fixed? Are results reproducible?
    7. Missing edge cases in the evaluation?
    
    Flag issues as CRITICAL (must fix) / MAJOR (should fix) / MINOR.
```

- If issues found: apply **Review Feedback Verification Protocol** — evaluate each finding, dispute incorrect ones via `/codex:rescue`. Confirmed CRITICAL issues must be fixed and re-reviewed (max 2 rounds). After fixes pass or 2 rounds exhausted, proceed to Step 2.
- If Codex CLI unavailable: skip review, proceed with self-review only

**Step 2: Sanity check**
- Run a quick sanity test (smallest dataset / fewest epochs) to verify no crashes
- **Auto-debug on failure** (max 3 attempts):
  1. Read error: parse traceback, stderr, logs
  2. Diagnose: OOM → reduce batch size; ImportError → install; CUDA error → check GPU; NaN → reduce LR
  3. Fix and re-run
  4. Still failing after 3 attempts → record failure, revert to best variant, skip to Phase E

**Step 2.5: Hyperparameter sensitivity** (after sanity passes)
- Identify the 2-3 key hyperparameters of the new variant (learning rate, loss weights, architectural dimensions)
- Run a small-scale sweep on the smallest dataset: 3-5 configurations per parameter (default, 0.5×, 2×, and optionally 0.1×, 5×)
- Can run configurations in parallel if multiple GPUs available
- Select the best configuration based on the primary metric
- Log sweep results to `innovation-logs/round-NN/hparam-sweep.md`
- If ALL configurations fail or significantly worsen: abort variant, skip to Phase E with HPARAM_FAIL flag

**Step 3: Multi-seed full evaluation**
- Deploy the best configuration from Step 2.5 via `/run-experiment`
- **Run with >= 3 seeds** (fixed seeds, e.g., 42, 123, 456) for statistical validity
- Monitor via `/monitor-experiment` (or direct log checking)
- If W&B configured: invoke `/training-check` to verify training health
- Wait for ALL seeds to complete

**Step 3.5: Early stopping check** (optional, for expensive experiments)
- After the first seed completes ~30% of training: check loss trajectory
- If loss is clearly diverging OR > 3× worse than baseline at the same training step: abort remaining seeds and training
- Skip to Phase E with EARLY_STOP flag — saves compute on obviously-bad variants
- If loss trajectory looks promising or ambiguous: continue all seeds to completion

**Step 4: Collect and compare results with statistical rigor**
- Parse output files from ALL seeds (JSON/CSV/logs)
- Compute **mean ± std** across seeds for every metric
- For main comparison vs baseline: compute **95% confidence interval** and **p-value** (paired t-test or Wilcoxon signed-rank, depending on normality)
- For comparison vs current best: same statistical protocol
- Build comparison table with statistical rigor:

  ```markdown
  | Method | Primary ↑/↓ | ± std | Secondary ↑/↓ | ± std | vs Baseline | p-value | Sig |
  |--------|-------------|-------|---------------|-------|-------------|---------|-----|
  | [PRIMARY_BASELINE] | X.XX | ±X.XX | X.XX | ±X.XX | — | — | — |
  | Best (v{best_round}) | X.XX | ±X.XX | X.XX | ±X.XX | ΔX% | p=X.XX | ** |
  | Current (v{N}) | X.XX | ±X.XX | X.XX | ±X.XX | ΔX% | p=X.XX | * |
  ```
  Significance: * p<0.05, ** p<0.01, *** p<0.001, NS = not significant

- Record per-task/per-scenario breakdown (important for robotics — different environments/tasks)
- Append to `score-history.csv`
- **Flag non-significant improvements as "NS"** — Phase E should treat NS improvements as "tied", not "improved"

Save to `innovation-logs/round-NN/results.md`.

### Phase D.5: Loss Function Experimentation (triggered on plateau)

**Skip entirely unless**: `patience_counter >= 2` AND no improvement in last 2 rounds. This phase fires when the method architecture seems sound but training isn't converging optimally — the loss function itself may be the bottleneck.

1. **Analyze current loss**: What loss function is being used? What are its known limitations for this problem type?

2. **Generate 2-3 loss variants** via Codex CLI:
   - **Variant L1**: Current loss + regularization term (e.g., L2 on key parameters, spectral normalization, consistency regularization, smoothness penalty)
   - **Variant L2**: Alternative loss family (e.g., Huber loss vs MSE for robustness to outliers, focal loss vs CE for class imbalance, contrastive auxiliary loss for representation quality)
   - **Variant L3**: Principled modification inspired by `TECHNIQUE_LIBRARY.md` distilled principles (e.g., if principle says "exploit known conservation laws" → add physics-informed loss term)

3. **Quick comparison** (1 seed, smallest dataset, reduced epochs): run all loss variants and current loss
4. **Select best**: if any variant improves primary metric by > 1 std → adopt for next round's full evaluation
5. **Log**: save loss comparison to `innovation-logs/round-NN/loss-experiment.md`

> 💡 Loss function changes often unlock plateaus that architectural changes cannot. This step is the equivalent of "try a different optimizer" but more principled.

---

### Phase E: Reflection and Learning (Memory Update)

**Goal**: Accumulate cross-round intelligence. This is where the loop gets smarter over time.

**Step 1: Score update**
- Record new metrics in `score-history.csv`:
  ```
  round,variant,primary_metric,secondary_metric,task_metric,score,macro_phase,timestamp
  ```

**Step 2: Improvement check**

| Result | Condition | Action |
|--------|-----------|--------|
| **Improved** | mean better AND p < 0.05 (statistically significant) | Update `best_variant`, `best_score`, `best_round`, `best_metrics`. Reset `patience_counter` to 0. Reset `regression_counter` to 0. **Run inline ablation** (Step 2.5 below). |
| **Tied** | mean better but p >= 0.05 (NOT statistically significant), OR within noise margin | Increment `patience_counter`. Keep current best. Log as "NS improvement — insufficient evidence." |
| **Slightly worse** | mean worse but within 1 std | Increment `patience_counter`. Keep current best. |
| **Significantly worse** | Increment `regression_counter`. If `regression_counter >= REGRESSION_TOLERANCE`: revert code to best variant and reset regression_counter. |

**Threshold guidance** (adapt to your domain):
- **Improved**: Primary metric (e.g., success rate, ATE, reward) shows absolute improvement beyond noise range (typically > 1-2% relative improvement, or > 1 standard deviation across seeds). If multiple metrics, majority must improve with none significantly regressing.
- **Tied**: Primary metric changes by less than noise range in either direction.
- **Slightly worse**: Primary metric regresses within 5% relative, or only on a minority of sequences.
- **Significantly worse**: Primary metric regresses by > 5% relative, or regresses on a majority of sequences.

**Step 2.5: Inline ablation** (only when variant IMPROVED over best)

When a variant is declared "Improved" (statistically significant), immediately verify it's NOT a confound:
1. **Remove the novel component** from the variant, keeping everything else (architecture, hyperparameters, training schedule)
2. **Quick run** (1 seed, smallest dataset): does improvement disappear?
3. **Interpret**:
   - Improvement disappears → **Confirmed causal contribution**. Proceed normally.
   - Improvement persists without novel component → **Confound detected**. The improvement comes from something else (hyperparameter change, data preprocessing, lucky configuration). Downgrade to "Tied" in EVOLUTION_LOG. Investigate what actually helped.
4. Log ablation result in `innovation-logs/round-NN/inline-ablation.md`
5. **Independent verification** (Codex Plugin — GPT-5.4 reads ablation results directly):
   ```
   /codex:rescue --effort high "Read innovation-logs/round-NN/inline-ablation.md and the actual experiment output files. Verify: does the ablation correctly isolate the novel component? Is the conclusion (causal vs confound) supported by the data? Any methodological issues?"
   ```
   If rescue disagrees with Claude's conclusion → downgrade to "Tied" and log the disagreement.

> This catches confounds DURING optimization, not just at paper-writing time. Skipping this step risks building on a false foundation for 20+ subsequent rounds.

**Step 2.7: Deep Failure Analysis** (only when variant REGRESSED or showed no improvement)

When a variant fails to improve (tied or worse), run rescue to understand WHY:

```
/codex:rescue --effort xhigh "Innovation round N variant FAILED (tied/regressed).
Read these files directly:
- innovation-logs/round-NN/results.md — this round's results
- innovation-logs/round-NN/innovation.md — the variant design
- src/ — the implementation code
- git diff — what was changed

Analyze:
1. IMPLEMENTATION CHECK: Was the variant implemented correctly per the design spec?
2. INTEGRATION CHECK: Did the new component conflict with existing modules?
3. ROOT CAUSE: Why did this variant fail? Distinguish:
   - Implementation bug (design is sound, code is wrong)
   - Integration conflict (design is sound, doesn't fit architecture)
   - Hypothesis wrong (the underlying principle doesn't apply here)
   - Insufficient tuning (might work with different hyperparameters)
4. SALVAGE: Can this variant be fixed? Propose concrete revised approach.
5. TECHNIQUE VERDICT: Should the technique be marked NEGATIVE or given another chance with different integration?

Produce a structured analysis."
```

Save to `innovation-logs/round-NN/failure-analysis.md`.

**Route based on rescue analysis:**
- **Implementation bug** → fix the bug → **re-run Step 1.1 (mandatory `/codex:adversarial-review`)** → re-test in the SAME round
- **Integration conflict** → note in TECHNIQUE_LIBRARY how to integrate properly → if fixable now: fix → **mandatory review** → retry; if complex: retry in next round
- **Hypothesis wrong** → mark technique as TESTED-NEGATIVE with specific reason
- **Insufficient tuning** → mark as TESTED-MIXED, suggest hyperparameter range for next attempt
- **Salvageable** → implement revised approach → **mandatory `/codex:adversarial-review --scope working-tree`** → re-test

> **Rule: ANY code change — including bug fixes from failure analysis — must pass Step 1.1 adversarial review before experiments.**

**GATE (outcome enforcement)**: Step 2.7 rescue's outcome must be persisted to state before Phase E Step 3 proceeds. Write to `innovation-logs/round-${N}/failure-analysis-verdict.json`:

```json
{
  "round": N,
  "outcome": "implementation_bug" | "integration_conflict" | "hypothesis_wrong" | "insufficient_tuning" | "salvageable",
  "retry_phase_d": true|false,
  "persist_to_wiki": true|false,
  "reasoning": "..."
}
```

Phase E Step 3 reads this file:
- If `retry_phase_d: true` and we have not yet retried this round → return to Phase D Step 1 with the revised approach (tracked via round sub-index: `round-${N}.${retry_count}`)
- If `retry_phase_d: false` → mark variant according to outcome enum, proceed to Step 3

Without this file, Phase E Step 3 halts — preventing silent deferral of "salvageable" outcomes.

**Persist failure to wiki (NEW — when the mechanistic cause is generalizable)**:

If the rescue analysis identified a mechanistic root cause (Hypothesis wrong, Integration conflict with a domain-agnostic trigger, or a systemic pattern not just hyperparameter sensitivity), upsert as a new failure-pattern to `research-wiki/failures/`:

```
If research-wiki/ exists AND rescue produced a generalizable mechanistic cause:
  Apply shared-references/failure-extraction.md 5-layer protocol to the rescue findings:
    Layer 1: Surface failure = the variant's regressed metric pattern
    Layer 2: Underlying trigger = rescue's mechanistic cause (domain-agnostic)
    Layer 3: Generalization = the condition under which any method with this principle would fail
    Layer 4: Adaptation check = does this apply beyond our project?
    Layer 5: Status = active (we did not resolve it)
  Then:
    /research-wiki upsert_failure-pattern <slug> — from: exp:<round-N-exp-id>
    add_edge(exp:<round-N-exp-id>, failure-pattern:<slug>, "manifested_as")
    for each principle in variant's PRINCIPLE GROUNDING:
        add_edge(failure-pattern:<slug>, principle:<slug>, "failure_mode_of")
```

This closes the loop: the loop's own failures become cross-project knowledge. Future projects will find this failure in the library before designing variants with the same principles.

**Step 2.9: Trajectory Reanalysis (MANDATORY at `round in TRAJECTORY_CHECKPOINTS = {15, 30, 45}`)** — see `../shared-references/reframing-triggers.md` Trigger 3.

At the three macro boundaries, diff the current winning lineage against round 0 commitments and ask: which early commitment now looks wrong given subsequent evidence? If the answer is strong enough, propose a **branch-reset** variant for round N+1.

**Fires at**: rounds {15, 30, 45} unconditionally (even if the round succeeded).

```
/codex:rescue --effort xhigh "
Apply shared-references/reframing-triggers.md Trigger 3 (Trajectory Reanalysis).

Read:
- innovation-logs/EVOLUTION_LOG.md — method lineage (full)
- innovation-logs/TECHNIQUE_LIBRARY.md — tested principles, especially TESTED-POSITIVE
- innovation-logs/score-history.csv — full progression
- innovation-logs/INNOVATION_STATE.json — current best, plateau deltas
- research-wiki/AUDIT_REPORT.md (if exists) — contextualize trends

Checkpoint: round {15 | 30 | 45}

Step 1 — Identify the single earliest commitment (rounds 0–5) that now looks questionable given what we have learned since.
Step 2 — Construct the branch-reset variant: take current best, replace the questionable commitment with the better one, keep everything else.
Step 3 — Estimate expected improvement and cost.
  - Expected improvement / current plateau delta
  - Cost vs one normal round
Step 4 — Decision:
  - If ratio > 1.5 AND cost < 2× a normal round: propose branch-reset as a required Phase C candidate for round N+1
  - If ratio ≤ 1.5: trajectory is sound; no reset
  - If cost prohibitive: log as 'retrospectively questionable' for post-loop reflection

Write to TRAJECTORY_REANALYSIS_CHECKPOINT_{15|30|45}.md.
"
```

If the decision is "propose branch-reset," the branch-reset variant is automatically added to Phase C's required variants in round N+1.

**GATE (non-skippable when `$N in {15, 30, 45}`)** — before Phase E Step 3 proceeds at checkpoint rounds, verify the trajectory reanalysis artifact exists:

```bash
if [ "$N" -eq 15 ] || [ "$N" -eq 30 ] || [ "$N" -eq 45 ]; then
    test -f "innovation-logs/TRAJECTORY_REANALYSIS_CHECKPOINT_${N}.md" || { echo "HALT: Trajectory Reanalysis mandatory at checkpoint round $N but artifact missing"; exit 1; }
fi
```

**Step 3: Technique library update**
- For each technique used in this round's variant:
  - If the round improved: mark as `TESTED-POSITIVE` (or update existing positive entry with conditions)
  - If the round regressed: mark as `TESTED-NEGATIVE` with specific conditions noted + rescue failure analysis
  - If mixed (some metrics improved, some regressed): mark as `TESTED-MIXED`
- Record specific conditions: "works when combined with X but not Y", "effective on walking sequences but not driving"
- **Include rescue's root cause and salvage recommendation** in the technique entry

**Step 4: Blacklist update**
- If a technique has been tested in 2+ different configurations and was `TESTED-NEGATIVE` each time → add to `BLACKLIST.md`:
  ```markdown
  ## [Technique] — BLACKLISTED
  - **Tested in**: Round X (config A), Round Y (config B)
  - **Result**: Negative in both cases
  - **Root cause of failure**: [specific reason]
  - **Exception**: Could reconsider if [very specific new information]
  ```

**Step 5: Evolution log update**
- Append to `EVOLUTION_LOG.md`:
  ```markdown
  ## Round N: v{N} — [variant name]
  - **Changed from v{N-1}**: [specific diff]
  - **Hypothesis**: [what we expected]
  - **Result**: [what actually happened — with numbers]
  - **Learning**: [what we learned that applies to future rounds]
  - **Decision**: KEEP / REVERT / PARTIAL KEEP (keep component A, revert B)
  - **Method lineage**: v0 → v3 → v7 → v9 → vN (winning path only)
  ```

**Step 6: Fusion candidate update**
- If two individually-tested techniques have complementary failure modes (A fails where B succeeds and vice versa), add to `FUSION_CANDIDATES.md`:
  ```markdown
  ## Candidate: [Technique A] + [Technique B]
  - **Rationale**: A improves [metric X] but degrades [metric Y]; B does the opposite
  - **Expected synergy**: Combining should improve both metrics
  - **Proposed integration**: [how to combine them architecturally]
  - **Priority**: HIGH/MEDIUM/LOW
  - **Status**: UNTESTED
  ```

**Step 7: Research Anchor drift check**
- Re-read the frozen Research Anchor
- Check: is the current method still aligned with the target venue, domain, and baseline?
- If drift detected (e.g., method has become too complex for a letter, or no longer comparable to baseline): flag and correct course in next round

**Step 8: Macro phase transition check + Problem Reframing Gate**

When a macro phase patience counter is about to trigger transition, first run **Problem Reframing** (see `../shared-references/reframing-triggers.md` Trigger 2). This is the gate that asks whether the next phase should even be entered on the same problem, or whether the loop should pivot to a reframed problem.

```
Problem Reframing Gate (fires BEFORE macro transition):

if (macro_phase == "explore" AND patience_counter >= PATIENCE_EXPLORE) OR
   (macro_phase == "refine" AND patience_counter >= PATIENCE_REFINE):

    /codex:rescue --effort xhigh "
    Apply shared-references/reframing-triggers.md Trigger 2 (Problem Reframing).

    Read:
    - Research Anchor (frozen, in innovation-logs/)
    - innovation-logs/score-history.csv (last 5 rounds — the plateau)
    - innovation-logs/TECHNIQUE_LIBRARY.md

    Produce up to 3 reframings, each tagged (metric | decomposition | family). For each:
    - Reframed problem statement
    - What changes, what stays
    - Cost vs restart
    - Recommendation: ADOPT | EVALUATE-FIRST | REJECT

    If top-ranked is ADOPT on a family reframing: write REFRAMING_DECISION.md and seed Phase A of the next round with the new method family (DO NOT transition to refine/polish on the old frame).
    If top-ranked is EVALUATE-FIRST: schedule a pilot round that tests the reframing cheaply before committing.
    If all REJECT: proceed with the normal macro transition below.
    "

    Read REFRAMING_DECISION.md:
    - If ADOPT: skip the macro transition logic below; next round starts in the reframed problem with fresh patience_counter = 0
    - If EVALUATE-FIRST: next round is a one-shot pilot of the reframed variant; transition decision deferred
    - If REJECT: proceed with normal macro transition below
```

**Normal macro transition (fires only if reframing gate REJECTED all reframings):**

```
if macro_phase == "explore":
    if patience_counter >= PATIENCE_EXPLORE:
        macro_phase = "refine"
        patience_counter = 0
        Log: "Transitioning from EXPLORE to REFINE — exploration plateau reached, reframings rejected"

elif macro_phase == "refine":
    if patience_counter >= PATIENCE_REFINE:
        macro_phase = "polish"
        patience_counter = 0
        Log: "Transitioning from REFINE to POLISH — refinement plateau reached, reframings rejected"

elif macro_phase == "polish":
    if patience_counter >= PATIENCE_POLISH:
        STOP LOOP
        Log: "POLISH patience exhausted — terminating"
```

Note: the reframing gate does NOT fire at the polish→terminate boundary. Polish is already the final phase — reframing at that point would restart the loop rather than transition. If polish exhausts, terminate.

**Step 9: Write state**
- Update `INNOVATION_STATE.json` with all current state
- If `COMPACT = true`: append one-line finding to `findings.md`:
  ```
  - [Round N] [positive/negative/mixed]: [one-sentence finding] (primary_metric: X.XX → Y.YY)
  ```

**Step 10: Human checkpoint** (if `HUMAN_CHECKPOINT = true`)
- Present round summary:
  ```
  🔬 Round N/MAX_ROUNDS complete.
  Macro phase: {explore/refine/polish}
  Score: X/10 — [verdict]
  Best so far: v{best_round} (score {best_score}/10)
  Improvement this round: [yes ΔX% / no / regression]
  Technique library: [N] techniques, [M] tested
  
  Options:
  - "go" → continue to next round
  - "focus on [topic]" → bias next round's research toward topic
  - "try [technique]" → force specific technique in next round
  - "skip to refine" → transition macro phase
  - "stop" → terminate loop
  ```

**Step 11: Feishu notification** (if `~/.claude/feishu.json` exists and mode not "off")
- Send `innovation_round` notification: "Round N: {score}/10 — v{N} {variant_name}"
- If interactive mode and score improved: send as milestone
- If interactive mode and regression: send as warning

Save to `innovation-logs/round-NN/reflection.md`.

→ **Increment round counter. Back to Phase A.**

---

## Stopping Conditions

Evaluate after each Phase E. Stop if ANY of these are true:

| # | Condition | Description |
|---|-----------|-------------|
| 1 | **Target met** | `score >= TARGET_SCORE` AND statistically significant improvement over `PRIMARY_BASELINE` on >= 2 sequences/scenarios |
| 2 | **Polish patience exhausted** | `macro_phase == "polish"` AND `patience_counter >= PATIENCE_POLISH` |
| 3 | **Max rounds reached** | `round >= MAX_ROUNDS` |
| 4 | **Stuck with regressions** | `regression_counter >= REGRESSION_TOLERANCE` AND `best_score` has not improved for >= `PATIENCE_REFINE` rounds |
| 5 | **User interrupt** | `HUMAN_CHECKPOINT=true` and user says "stop" |

---

## Termination

When the loop ends (by any stopping condition):

1. **Write `FINAL_METHOD.md`**: Complete description of the best variant (v{best_round}):
   - Architecture diagram (text-based)
   - Mathematical formulation
   - Key design decisions and why
   - Comparison with baseline (full metrics table)
   - Known limitations
   - Suggested future improvements

2. **Finalize `EVOLUTION_LOG.md`**: Add summary section:
   ```markdown
   ## Summary
   - Total rounds: [N]
   - Macro phase reached: [explore/refine/polish]
   - Method lineage (winning path): v0 → ... → v{best}
   - Techniques explored: [N], positive: [M], negative: [K]
   - Key breakthrough round: [round number and what changed]
   - Final improvement over baseline: [metrics]
   ```

3. **Update `INNOVATION_STATE.json`**: Set `status: "completed"`

4. **Generate claims**: Invoke `/result-to-claim` with best variant's results to produce `CLAIMS_FROM_RESULTS.md`. Bridges to paper writing workflow.

5. **Write method description**: Append a `## Method Description` section to `FINAL_METHOD.md` — a 1-2 paragraph concise description of the final method, architecture, and data flow, suitable for `/paper-illustration` to auto-generate architecture diagrams.

6. **Novelty snapshot**: If rounds >= 20, invoke `/novelty-check` on the final method to verify it's still novel after all the evolution.

7. **Suggest next steps**:
   ```
   🏁 Deep innovation loop complete.
   
   Best: v{best_round} — score {best_score}/10
   Improvement over [PRIMARY_BASELINE]: [ΔX%] primary_metric, [ΔY%] secondary_metric
   
   Next steps:
   → /auto-review-loop "[topic]" — 2-3 rounds of paper-level polish
   → /paper-plan "[topic]" — venue: [VENUE] — plan the paper structure
   → /paper-write "[topic]" — venue: [VENUE] — write the paper
   ```

8. **Feishu notification** (if configured): Send `pipeline_done` with final score progression table.

---

## Key Rules

### Execution
- Large file handling: If Write fails due to size, retry with Bash (`cat << 'EOF' > file`) silently — do not ask user for permission
- ALWAYS use `config: {"model_reasoning_effort": "xhigh"}` for maximum reasoning depth
- Each round uses a fresh `/codex:rescue` call — GPT-5.4 reads the latest files directly. Context accumulates in innovation-logs/ which GPT-5.4 reads.
- Work AUTONOMOUSLY — do not ask user for permission at each round (unless HUMAN_CHECKPOINT=true)
- If experiment > 30 minutes, launch it and continue with other work while waiting

### Web Resilience (Critical for Pipeline Stability)
- **NEVER let web operations block the pipeline.** WebSearch and WebFetch can hang indefinitely — treat them as unreliable.
- **Prefer API tools over WebSearch/WebFetch**:
  - arXiv: `python tools/arxiv_fetch.py search "query"` (reliable, fast, categories: cs.RO, cs.AI, cs.LG)
  - Semantic Scholar: `python tools/semantic_scholar_fetch.py search "query"` (reliable, fast, venues: RA-L, ICRA, IROS, TRO, CoRL, RSS)
  - For known URLs: `curl -sL --max-time 30 "URL"` (has built-in timeout)
- **Timeout rule**: If WebSearch/WebFetch does not respond within ~60 seconds, abandon it immediately. Do NOT retry the same query — reformulate or skip.
- **Phase B is supplementary, not blocking**: If all literature searches fail in Phase B, proceed to Phase C using existing `TECHNIQUE_LIBRARY.md`. Log `[WEB UNAVAILABLE]` and continue.
- **Sub-agent scope**: When launching Agent sub-tasks for web research, keep each agent focused on ONE specific query. Broad "search everything" agents are more likely to hang.
- **Fallback chain**: WebSearch fails → try API tool → try `curl --max-time 30` → skip and continue

### Anti-Hallucination
- When adding references in any document: NEVER fabricate BibTeX
- Use DBLP → CrossRef → `[VERIFY]` chain:
  1. `curl -s "https://dblp.org/search/publ/api?q=TITLE&format=json"` → get key → `curl -s "https://dblp.org/rec/{key}.bib"`
  2. If not found: `curl -sLH "Accept: application/x-bibtex" "https://doi.org/{doi}"`
  3. If both fail: mark with `% [VERIFY]`

### Innovation Discipline
- **Every variant must change at most 1-2 components** from the current best. Too many changes = cannot attribute improvement. This is the SINGLE MOST IMPORTANT rule for productive iteration.
- **Never re-test blacklisted approaches** — unless genuinely new information justifies it (document why)
- **Anti-circle detection**: Before implementing, compare against last 5 variants. Reject near-duplicates.
- **Build on winners**: Always branch from `best_variant`, never from a variant that regressed
- **Negative results are valuable**: Document what doesn't work and why. This prevents future re-exploration.
- **Exhaust before surrendering**: Before marking a root cause as "cannot address," try at least 2 different solution paths. Only then concede narrowly — never give up on first attempt.

### Quality
- Be honest: include negative results and failed experiments
- Do NOT hide weaknesses to game a positive score
- Implement fixes BEFORE re-reviewing (don't just promise)
- Every experiment must have fixed random seeds, proper logging, and parseable output (JSON/CSV)
- Document EVERYTHING — the innovation log should be self-contained and reproducible

### Domain Awareness (Robotics Defaults)
- **Key metrics**: task success rate, completion time, trajectory error, sample efficiency, sim-to-real transfer gap (adapt to your sub-domain)
- **Key challenges**: sim-to-real transfer, sample efficiency, generalization across environments, contact-rich manipulation, safe exploration
- **Key techniques to explore**: imitation learning, reinforcement learning, policy distillation, world models, foundation models for robotics, diffusion policies, attention mechanisms, physics-informed losses
- **Key baselines**: specify for your sub-domain (e.g., DAgger, PPO, SAC, RT-2, PointNet++, RRT*, ORB-SLAM3)
- **Key datasets**: specify for your sub-domain (e.g., RLBench, CALVIN, Open X-Embodiment, nuScenes, KITTI, Habitat, MuJoCo benchmarks)
- **Venue awareness**: RA-L/ICRA/IROS expect real-world experimental validation; CoRL/RSS value novel learning methods; all expect ablation studies

### Integration with ARIS Skills

This skill composes with existing skills — invoke them as needed:

| Skill | When to use |
|-------|-------------|
| `/research-lit` | Phase B: broad literature search |
| `/arxiv` | Phase B: arXiv paper fetching |
| `/semantic-scholar` | Phase B: venue paper search (RAL/ICRA/IROS/TRO) |
| `/run-experiment` | Phase D: experiment deployment |
| `/monitor-experiment` | Phase D: progress monitoring |
| `/training-check` | Phase D: training quality verification |
| `/analyze-results` | Phase D: result analysis |
| `/result-to-claim` | Termination: claim validation |
| `/novelty-check` | Periodic: novelty verification (every 10-15 rounds) |
| `/ablation-planner` | Polish phase: design ablation studies |
| `/auto-review-loop` | Post-termination: final paper-level polish |

---

## Example Invocations

```
# Full pipeline for robot manipulation research
/deep-innovation-loop "improve dexterous manipulation with policy learning" — \
  baseline: DAgger, venue: CoRL, domain: manipulation, \
  human checkpoint: false, max rounds: 40

# With human checkpoints for manual guidance
/deep-innovation-loop "novel vision-based navigation method" — \
  baseline: PointNav-SLAM, venue: RA-L, domain: navigation, human checkpoint: true

# Specify compute constraints
/deep-innovation-loop "locomotion with transformer world model" — \
  baseline: PPO, venue: RSS, domain: locomotion, max rounds: 30, \
  compact: true

# Resume from previous session (automatic if INNOVATION_STATE.json exists)
/deep-innovation-loop "continue"
```

## Composing with Research Pipeline

The `deep-innovation-loop` can be invoked from `/research-pipeline` by setting `DEEP_INNOVATION=true`:

```
/research-pipeline "robot manipulation" — deep innovation: true, baseline: DAgger, venue: CoRL, domain: manipulation
```

This chains: `/idea-discovery` → implement → `/deep-innovation-loop` → `/auto-review-loop` (polish) → `/paper-write`

## Review Tracing

After each `codex exec` reviewer call, save the trace following `../shared-references/review-tracing.md`. Use `bash tools/save_trace.sh` or write files directly to `.aris/traces/deep-innovation-loop/<date>_run<NN>/`. Respect the `--- trace:` parameter (default: `full`).
