---
name: deep-innovation-loop
description: "Autonomous deep research innovation loop for ML methods. Iteratively diagnoses root causes, researches literature for solutions, synthesizes novel method variants, tests them, and evolves the approach over 40+ rounds. Unlike auto-review-loop (symptom-fixing), this skill drives genuine methodological innovation with cumulative knowledge. Use when user says \"deep innovation\", \"evolve method\", \"deep loop\", \"innovate\", \"方法进化\", \"深度创新\", or wants autonomous method evolution beyond simple review-fix cycles."
argument-hint: [method-description-or-research-brief — baseline: AIR-IO, venue: RAL, domain: inertial odometry]
allowed-tools: Bash(*), Read, Write, Edit, Grep, Glob, WebSearch, WebFetch, Agent, Skill, mcp__codex__codex, mcp__codex__codex-reply
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
| `FUSION_INTERVAL` | 5 | Every N rounds, run a special "fusion optimization" round |
| `REVIEWER_MODEL` | gpt-5.4 | External reviewer model via Codex MCP |
| `HUMAN_CHECKPOINT` | false | When true, pause after each round's diagnosis for user input |
| `COMPACT` | false | When true, use compact logs for session recovery |
| `VENUE` | RAL | Target venue (IEEE Robotics and Automation Letters) |
| `DOMAIN` | inertial odometry | Research domain |
| `PRIMARY_BASELINE` | AIR-IO | Primary comparison baseline |

Override inline: `/deep-innovation-loop "improve inertial odometry" — baseline: AIR-IO, venue: RAL, max rounds: 40, human checkpoint: true`

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
├── score-history.csv               # Metric progression (ATE, RTE, drift, etc.)
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
  "current_variant": "v12-gravity-aware-attention",
  "patience_counter": 2,
  "regression_counter": 0,
  "explored_techniques": ["adaptive_ekf", "gravity_compensation", "attention_fusion"],
  "failed_approaches": ["raw_lstm:no_physics_awareness", "naive_transformer:drift_accumulation"],
  "baseline_metrics": {"ATE": 1.23, "RTE": 0.45},
  "best_metrics": {"ATE": 0.89, "RTE": 0.31},
  "pending_experiments": ["screen_exp_v12"],
  "metrics_history": [
    {"round": 0, "variant": "AIR-IO-baseline", "ATE": 1.23, "RTE": 0.45, "score": 4.0}
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

Always use `config: {"model_reasoning_effort": "xhigh"}`.

**Round 1** — start a new Codex thread:
```
mcp__codex__codex:
  config: {"model_reasoning_effort": "xhigh"}
  prompt: |
    [Round 1/MAX_ROUNDS — ROOT CAUSE DIAGNOSIS]
```

**Round 2+** — continue the existing thread (preserves full conversation history):
```
mcp__codex__codex-reply:
  threadId: [saved from Round 1]
  config: {"model_reasoning_effort": "xhigh"}
  prompt: |
    [Round N/MAX_ROUNDS — ROOT CAUSE DIAGNOSIS]
```

Save the `threadId` from the Round 1 response. Use it for ALL subsequent rounds.

**Prompt content (same for both)**:
```
  prompt: |
    [Round N/MAX_ROUNDS — ROOT CAUSE DIAGNOSIS]
    
    Domain: [DOMAIN]
    Target venue: [VENUE]
    Primary baseline: [PRIMARY_BASELINE]
    
    Current method (v{N-1}): [complete method description]
    
    Latest results:
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
       so gyroscope bias is unobservable")
    3. CAUSAL CHAIN: Symptom ← Intermediate cause ← Root cause
    4. ANALOGIES: Has this root cause been solved in adjacent fields?
       (SLAM, VIO, visual odometry, sensor fusion, state estimation, 
       signal processing, control theory)
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

### Phase B: Targeted Literature Research (Conditional)

**Goal**: Find techniques from the literature that address newly identified root causes.

**Trigger conditions** (Phase B is NOT executed every round — it triggers only when):
- Phase A identified a root cause NOT already covered in `TECHNIQUE_LIBRARY.md`
- At least `LIT_SEARCH_COOLDOWN` rounds have passed since last search on the same topic
- Phase A identified a promising analogy to another field

**If none of these conditions are met**: Skip Phase B, proceed directly to Phase C using existing knowledge from `TECHNIQUE_LIBRARY.md`.

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
      python tools/arxiv_fetch.py search "inertial odometry gravity compensation"
      ```
      - Keywords: combine domain terms + root cause concept
      - Example: `"inertial odometry" AND "gravity compensation"`, 
        `"IMU preintegration" AND "bias estimation"`, `"neural inertial" AND "attention"`
      - Focus on last 2 years, categories: cs.RO, eess.SP, cs.CV
      - Only use WebSearch as fallback if the API tool fails
   
   b. **Semantic Scholar** — PREFER the API tool over WebSearch:
      ```bash
      # Primary: reliable API tool with built-in timeout
      python tools/semantic_scholar_fetch.py search "inertial odometry" --year 2024-2026
      ```
      - Target venues: RAL, ICRA, IROS, TRO, CoRL, RSS
      - Also check adjacent: IEEE TSP, ICASSP, NeurIPS, ICML (for method innovations)
      - Filter by citation count and recency
   
   c. **Adjacent domain search** (WebSearch acceptable here, with timeout):
      - If root cause is "drift accumulation" → search SLAM loop closure techniques
      - If root cause is "sensor noise" → search signal processing / Kalman filtering
      - If root cause is "temporal modeling" → search sequence modeling / transformers
      - If root cause is "physics mismatch" → search physics-informed neural networks
      - **If WebSearch hangs (~60s), abandon and skip** — adjacent domain search is supplementary, not critical

   **Web Resilience**: If ANY web operation hangs, abandon it immediately and continue with already-collected results. Phase B must NEVER block the pipeline. If all searches fail, proceed to Phase C using existing `TECHNIQUE_LIBRARY.md` knowledge and note `[WEB SEARCH UNAVAILABLE]` in the round's research log.

3. **Extract and catalog**: For each relevant technique found:

   ```markdown
   ## [Technique Name] — [Source Field]
   
   - **Paper**: [full citation]
   - **Root cause addressed**: [which root cause from Phase A this solves]
   - **Mechanism**: [1-2 sentence technical description]
   - **Mathematical formulation**: [key equations if applicable]
   - **Reported improvement**: [quantitative, with dataset/benchmark caveats]
   - **Integration cost**: LOW (config/loss change) / MEDIUM (new module) / HIGH (architecture change)
   - **Compatibility with current architecture**: [specific notes]
   - **Status**: UNTESTED
   - **Tested in round(s)**: []
   - **Synergy potential**: [which other techniques it could combine with, and why]
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

**Special case — Fusion Round** (triggered when `round % FUSION_INTERVAL == 0`, e.g., rounds 5, 10, 15, 20...):

Replace normal Phase C with a fusion-specific round:

1. Read `TECHNIQUE_LIBRARY.md` — identify all `TESTED-POSITIVE` and `TESTED-MIXED` techniques
2. Read `FUSION_CANDIDATES.md` for pre-identified synergy pairs
3. For each candidate combination:
   - Does technique A's strength compensate for technique B's weakness?
   - Are they architecturally compatible (no conflicting assumptions)?
   - Has this exact combination been tested before?
4. Submit fusion candidates to GPT-5.4 for ranking via `mcp__codex__codex-reply`:
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

**Normal round — Innovation proposal via Codex MCP:**

```
mcp__codex__codex-reply:
  threadId: [saved from Phase A]
  config: {"model_reasoning_effort": "xhigh"}
  prompt: |
    [Round N — INNOVATION DESIGN]
    
    Root causes from diagnosis:
    [paste key findings from Phase A]
    
    Available techniques from our library:
    [paste relevant TECHNIQUE_LIBRARY.md entries — prioritize UNTESTED and TESTED-MIXED]
    
    Current best method (v{best_round}, score {best_score}/10):
    [complete description]
    
    Current method (v{N-1}) if different from best:
    [description and how it differs]
    
    BLACKLISTED approaches — do NOT propose anything similar:
    [paste from BLACKLIST.md]
    
    Macro phase: {explore/refine/polish}
    Research Anchor: [paste frozen anchor]
    
    TASK: Propose 2-3 method variants that address the identified root causes.
    
    For EACH variant:
    1. NAME: descriptive variant name (e.g., "v12-gravity-aware-attention")
    2. HYPOTHESIS: What specific improvement do you expect and why?
    3. MECHANISM: Exactly what changes from current best method
    4. TECHNIQUE FUSION: Which techniques from the library are combined?
    5. WHY 1+1>2: Why does combining these techniques create synergy?
       (e.g., "Technique A provides gravity-aware features, which makes 
       Technique B's attention mechanism focus on motion-relevant signals 
       instead of sensor noise, amplifying both effects")
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

**Adversarial Challenge** (GPT-5.4 plays devil's advocate on the proposed variants):

After receiving the variant proposals, immediately challenge them in the same thread:

```
mcp__codex__codex-reply:
  threadId: [saved]
  config: {"model_reasoning_effort": "xhigh"}
  prompt: |
    [Round N — ADVERSARIAL CHALLENGE]
    
    You proposed these variants. Now play DEVIL'S ADVOCATE.
    For EACH variant:
    
    1. FATAL FLAW: What is the single strongest reason this will NOT work?
    2. HIDDEN ASSUMPTION: What assumption are you making that might be wrong?
    3. EASIER ALTERNATIVE: Is there a simpler approach that achieves the 
       same goal without this complexity?
    4. EVALUATION TRAP: How could this variant appear to improve metrics 
       but actually be a flawed improvement (e.g., overfitting, unfair 
       comparison, metric gaming)?
    5. SURVIVAL VERDICT: After your own critique, which variant(s) survive?
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

**Anti-circle check**: Before implementing, compare the selected variant against the last 5 variants in `EVOLUTION_LOG.md`. If the proposed change is essentially identical to a previously tried variant (same technique combination, same integration point), reject it and request a different proposal.

Save to `innovation-logs/round-NN/innovation.md` (include both proposals AND adversarial critique).

---

### Phase D: Implementation and Evaluation

**Goal**: Implement the selected variant, run experiments, and compare against baseline + current best.

**Step 1: Implement**
- Make the code changes described in the selected variant
- Self-review: does the implementation match the design?
- Code quality: proper seeding, logging, result saving

**Step 1.5: Experiment Design + Code Review (Codex MCP)**

Before deploying, submit the experiment design AND implementation to GPT-5.4 for review:

```
mcp__codex__codex-reply:
  threadId: [saved]
  config: {"model_reasoning_effort": "xhigh"}
  prompt: |
    [Round N — EXPERIMENT DESIGN & CODE REVIEW]
    
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

- If CRITICAL issues found: Claude Opus 4.6 (the executor) implements the fixes, then re-submits for review (max 2 review rounds). After fixes pass or 2 rounds exhausted, proceed to Step 2.
- If Codex MCP unavailable: skip review, proceed with self-review only

**Step 2: Sanity check**
- Run a quick sanity test (smallest dataset / fewest epochs) to verify no crashes
- **Auto-debug on failure** (max 3 attempts):
  1. Read error: parse traceback, stderr, logs
  2. Diagnose: OOM → reduce batch size; ImportError → install; CUDA error → check GPU; NaN → reduce LR
  3. Fix and re-run
  4. Still failing after 3 attempts → record failure, revert to best variant, skip to Phase E

**Step 3: Full evaluation**
- Deploy via `/run-experiment [experiment command]`
- Monitor via `/monitor-experiment` (or direct log checking)
- If W&B configured: invoke `/training-check` to verify training health
- Wait for completion

**Step 4: Collect and compare results**
- Parse output files (JSON/CSV/logs)
- Build comparison table:

  ```markdown
  | Method | Seq1 ATE | Seq2 ATE | ... | Mean ATE ↓ | Mean RTE ↓ | vs Baseline | vs Best |
  |--------|----------|----------|-----|-----------|-----------|-------------|---------|
  | [PRIMARY_BASELINE] | ... | ... | ... | X.XX | X.XX | — | — |
  | Best (v{best_round}) | ... | ... | ... | X.XX | X.XX | ΔX% | — |
  | Current (v{N}) | ... | ... | ... | X.XX | X.XX | ΔX% | ΔX% |
  ```

- Record per-sequence breakdown (important for inertial odometry — different motion types)
- Append to `score-history.csv`

Save to `innovation-logs/round-NN/results.md`.

---

### Phase E: Reflection and Learning (Memory Update)

**Goal**: Accumulate cross-round intelligence. This is where the loop gets smarter over time.

**Step 1: Score update**
- Record new metrics in `score-history.csv`:
  ```
  round,variant,ATE,RTE,drift,score,macro_phase,timestamp
  ```

**Step 2: Improvement check**

| Result | Action |
|--------|--------|
| **Improved** over current best | Update `best_variant`, `best_score`, `best_round`, `best_metrics`. Reset `patience_counter` to 0. Reset `regression_counter` to 0. |
| **Tied** (within noise margin) | Increment `patience_counter`. Keep current best. |
| **Slightly worse** | Increment `patience_counter`. Keep current best. |
| **Significantly worse** | Increment `regression_counter`. If `regression_counter >= REGRESSION_TOLERANCE`: revert code to best variant and reset regression_counter. |

**Threshold guidance** (adapt to your domain):
- **Improved**: Primary metric (e.g., mean ATE) shows absolute improvement beyond noise range (typically > 1-2% relative improvement, or > 1 standard deviation across seeds). If multiple metrics, majority must improve with none significantly regressing.
- **Tied**: Primary metric changes by less than noise range in either direction.
- **Slightly worse**: Primary metric regresses within 5% relative, or only on a minority of sequences.
- **Significantly worse**: Primary metric regresses by > 5% relative, or regresses on a majority of sequences.

**Step 3: Technique library update**
- For each technique used in this round's variant:
  - If the round improved: mark as `TESTED-POSITIVE` (or update existing positive entry with conditions)
  - If the round regressed: mark as `TESTED-NEGATIVE` with specific conditions noted
  - If mixed (some metrics improved, some regressed): mark as `TESTED-MIXED`
- Record specific conditions: "works when combined with X but not Y", "effective on walking sequences but not driving"

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

**Step 8: Macro phase transition check**

```
if macro_phase == "explore":
    if patience_counter >= PATIENCE_EXPLORE:
        macro_phase = "refine"
        patience_counter = 0
        Log: "Transitioning from EXPLORE to REFINE — exploration plateau reached"

elif macro_phase == "refine":
    if patience_counter >= PATIENCE_REFINE:
        macro_phase = "polish"
        patience_counter = 0
        Log: "Transitioning from REFINE to POLISH — refinement plateau reached"

elif macro_phase == "polish":
    if patience_counter >= PATIENCE_POLISH:
        STOP LOOP
        Log: "POLISH patience exhausted — terminating"
```

**Step 9: Write state**
- Update `INNOVATION_STATE.json` with all current state
- If `COMPACT = true`: append one-line finding to `findings.md`:
  ```
  - [Round N] [positive/negative/mixed]: [one-sentence finding] (ATE: X.XX → Y.YY)
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
   Improvement over [PRIMARY_BASELINE]: [ΔX%] ATE, [ΔY%] RTE
   
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
- Save `threadId` from first Codex call, use `mcp__codex__codex-reply` for ALL subsequent rounds
- Work AUTONOMOUSLY — do not ask user for permission at each round (unless HUMAN_CHECKPOINT=true)
- If experiment > 30 minutes, launch it and continue with other work while waiting

### Web Resilience (Critical for Pipeline Stability)
- **NEVER let web operations block the pipeline.** WebSearch and WebFetch can hang indefinitely — treat them as unreliable.
- **Prefer API tools over WebSearch/WebFetch**:
  - arXiv: `python tools/arxiv_fetch.py search "query"` (reliable, fast)
  - Semantic Scholar: `python tools/semantic_scholar_fetch.py search "query"` (reliable, fast)
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

### Domain Awareness (Inertial Odometry Defaults)
- **Key metrics**: ATE (Absolute Trajectory Error), RTE (Relative Trajectory Error), heading drift, position drift rate
- **Key challenges**: gyroscope bias estimation, gravity compensation, cumulative drift, sensor noise
- **Key techniques to explore**: EKF/UKF state estimation, IMU preintegration, attention mechanisms for temporal data, physics-informed losses, gravity-aware architectures, multi-scale temporal modeling
- **Key baselines**: AIR-IO, TLIO, RoNIN, RINS-W, IONet, MotionTransformer
- **Key datasets**: RIDI, OxIOD, RoNIN dataset, KITTI (IMU), EuRoC MAV, TUM-VI
- **Venue awareness**: RAL expects real-world experimental validation, runtime analysis, ablation studies

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
# Full pipeline for inertial odometry research
/deep-innovation-loop "improve pure inertial odometry using deep learning" — \
  baseline: AIR-IO, venue: RAL, domain: inertial odometry, \
  human checkpoint: false, max rounds: 40

# With human checkpoints for manual guidance
/deep-innovation-loop "novel IMU-based navigation method" — \
  baseline: AIR-IO, venue: RAL, human checkpoint: true

# Specify compute constraints
/deep-innovation-loop "inertial odometry with transformer" — \
  baseline: AIR-IO, venue: RAL, max rounds: 30, \
  compact: true

# Resume from previous session (automatic if INNOVATION_STATE.json exists)
/deep-innovation-loop "continue"
```

## Composing with Research Pipeline

The `deep-innovation-loop` can be invoked from `/research-pipeline` by setting `DEEP_INNOVATION=true`:

```
/research-pipeline "inertial odometry" — deep innovation: true, baseline: AIR-IO, venue: RAL
```

This chains: `/idea-discovery` → implement → `/deep-innovation-loop` → `/auto-review-loop` (polish) → `/paper-write`
