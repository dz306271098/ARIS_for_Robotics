---
name: deep-innovation-loop
description: "Autonomous deep research innovation loop for ML methods. Iteratively diagnoses root causes, researches literature for solutions, synthesizes novel method variants, tests them, and evolves the approach over 40+ rounds. Unlike auto-review-loop (symptom-fixing), this skill drives genuine methodological innovation with cumulative knowledge. Use when user says \"deep innovation\", \"evolve method\", \"deep loop\", \"innovate\", \"方法进化\", \"深度创新\", or wants autonomous method evolution beyond simple review-fix cycles."
argument-hint: [method-description-or-research-brief — baseline: <your_baseline>, venue: <target_venue>, domain: <your_domain>]
allowed-tools: Bash(*), Read, Write, Edit, Grep, Glob, WebSearch, WebFetch, Agent, Skill
---

> Override for Codex users who want **Claude Code**, not a second Codex agent, to act as the reviewer. Install this package **after** `skills/skills-codex/*`.

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
| `REVIEWER_MODEL` | gpt-5.4 | External reviewer model via the local `claude-review` MCP bridge |
| `HUMAN_CHECKPOINT` | false | When true, pause after each round's diagnosis for user input |
| `COMPACT` | false | When true, use compact logs for session recovery |
| `VENUE` | RAL | Target venue (IEEE Robotics and Automation Letters) |
| `DOMAIN` | robotics | Research domain (override for your specific sub-domain, e.g., manipulation, navigation, locomotion) |
| `PRIMARY_BASELINE` | "" | Primary comparison baseline (must be specified by user, e.g., PointNet++, RRT*, DAgger, SLAM baseline) |
| `MANDATORY_TEST_GATE` | true | Every implementation round must pass the shared execution test gate before deployment or review handoff |
| `CONVERGENCE_MEMO_ROUND` | 3 | After 3 dispute turns on one reviewer issue, write a convergence memo |
| `MAX_REVIEW_DISPUTE_ROUNDS` | 5 | After 5 dispute turns, stop debating and request a resolution-only action plan |
| `AUTONOMY_PROFILE` | `CODEX.md -> ## Autonomy Profile` | Unattended-safe host policy for retries, watchdog, W&B, and cloud boundaries |
| `AUTONOMY_STATE` | `AUTONOMY_STATE.json` | Cross-workflow state anchor kept in sync with `INNOVATION_STATE.json` |

Override inline: `/deep-innovation-loop "improve robot manipulation" — baseline: DAgger, venue: CoRL, domain: manipulation, max rounds: 40, human checkpoint: true`

## Full Autonomy Principle

This loop is designed to run **fully autonomously for 40+ rounds without human intervention**. At every decision point:

1. **Never block** — make the best decision based on available data, document reasoning, continue.
2. **Auto-select variants** — after external adversarial challenge, the Codex executor selects the surviving variant with the best expected improvement. No user approval needed.
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
│   ├── test-gate.md                #   Mandatory test gate evidence
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

## Unattended Safe Mode

When `CODEX.md -> ## Autonomy Profile` sets `autonomy_mode: unattended_safe`, also follow `../shared-references/unattended-runtime-protocol.md`:

- keep `HUMAN_CHECKPOINT=false` unless a hard safety boundary blocks the current round
- update `AUTONOMY_STATE.json` before diagnosis, before implementation/eval, during wait states, and when the loop terminates or blocks
- do not auto-provision new cloud GPUs when `allow_auto_cloud: false`
- treat missing reviewer runtime or required W&B coverage as blockers instead of soft warnings

## Execution Rule

Follow the phases in order. Do **not** stop unless a stopping condition is met. Work AUTONOMOUSLY — do not ask user for permission at each round unless `HUMAN_CHECKPOINT=true`.

## Initialization

1. **Check for recovery**: Read `innovation-logs/INNOVATION_STATE.json`. Apply recovery logic above.

2. **Read project context**: Load `RESEARCH_BRIEF.md` or `CODEX.md` for problem context. If `research-wiki/query_pack.md` exists, read it before freezing the research anchor and treat failed ideas as a banlist plus open gaps as literature seeds. Also read `research-wiki/principle_pack.md`, `analogy_pack.md`, and `failure_pack.md` when present so the loop starts from accumulated transferable knowledge instead of only raw history. Read existing codebase to understand current method implementation.

3. **Freeze the Research Anchor** (immutable throughout the loop):

   ```markdown
   ## Research Anchor
   - **Target venue**: [VENUE]
   - **Primary baseline**: [PRIMARY_BASELINE]
   - **Domain**: [DOMAIN]
   - **Must-beat metrics**: [from CODEX.md or RESEARCH_BRIEF.md]
   - **Hardware constraints**: [from CODEX.md — GPU type, count, time budget]
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

**Collaborative Root-Cause Reanalysis** (see `../shared-references/collaborative-protocol.md`):

If `patience_counter >= 3` (no improvement for 3+ rounds), the current diagnosis may be WRONG. Before running the normal Phase A, trigger:

**Step 0: Independent diagnosis from raw files** (fresh reviewer, no trust in prior summaries):
```
mcp__claude-review__review_start:
  prompt: |
    STUCK-STATE ROOT CAUSE DIAGNOSIS

    We've been stuck for {patience_counter} rounds with no improvement.
    Read the last 3 rounds of results in innovation-logs/, plus
    TECHNIQUE_LIBRARY.md, score-history.csv, EVOLUTION_LOG.md, and the
    current src/ implementation. Do not trust prior summaries.

    Return:
    1. current_root_cause: best explanation of the plateau
    2. alternative_root_causes: ranked list
    3. strongest evidence_from_files: specific signals that support your diagnosis
    4. what_we_are_misreading: likely wrong assumptions in the current loop
```

After this start call, immediately save the returned `jobId` and poll `mcp__claude-review__review_status` with a bounded `waitSeconds` until `done=true`. Treat the completed status payload's `response` as the reviewer output, and save the completed `threadId` for any follow-up round.

Append these independent findings to the collaborative context below and save the reviewer agent id for follow-up.

**Step 1: Collaborative reanalysis** (multi-turn, with the saved reviewer thread):
```
mcp__claude-review__review_reply_start:
  threadId: [saved diagnosis agent id]
  prompt: |
    [COLLABORATIVE MODE - JOINT ROOT-CAUSE REANALYSIS]

    Previous diagnosis:
    [root cause from last Phase A]

    What was tried:
    [attempted variants and outcomes]

    My implementation evidence:
    [what the executor observed while changing code and running experiments]

    Reassess:
    1. Given both the raw files and the implementation evidence, is the old diagnosis still correct?
    2. What alternative root causes better explain the plateau?
    3. Is there a deeper structural issue we are both missing?
    4. What broader literature direction should Phase B explore if the diagnosis changes?
```

After this start call, immediately save the returned `jobId` and poll `mcp__claude-review__review_status` with a bounded `waitSeconds` until `done=true`. Treat the completed status payload's `response` as the reviewer output, and save the completed `threadId` for any follow-up round.

Continue up to 4 turns if needed. If a NEW root cause is identified, update the diagnosis and proceed to Phase B/C with the revised understanding. If the diagnosis holds, proceed normally but with a broader search strategy in Phase B.

Log to `innovation-logs/round-NN/collaborative-reanalysis.md`.

Always use maximum reasoning depth for these diagnosis reviews.

**Every round** — use a fresh reviewer agent so the diagnosis reflects the latest files, not stale conversation state:

```
mcp__claude-review__review_start:
  prompt: |
    [Round N/MAX_ROUNDS - ROOT CAUSE DIAGNOSIS]
    
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

After this start call, immediately save the returned `jobId` and poll `mcp__claude-review__review_status` with a bounded `waitSeconds` until `done=true`. Treat the completed status payload's `response` as the reviewer output, and save the completed `threadId` for any follow-up round.

**CRITICAL**: Save the FULL raw response verbatim. Save the reviewer agent id from the response so later follow-ups can reference it if needed.

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
5. **Write back distilled principles**: if `research-wiki/` exists, write or update the corresponding `principle:` page and rebuild packs with `python3 tools/research_wiki.py rebuild_packs research-wiki/`.

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
4. Submit fusion candidates to a reviewer agent for ranking:
   ```
mcp__claude-review__review_start:
  prompt: |
    [Round N - FUSION OPTIMIZATION]

    These techniques have been individually tested. Rank the following
    fusion combinations by expected synergy, considering architectural
    compatibility and complementary strengths:
    [paste candidate combinations with individual test results]

    For each combination, return:
    1. expected_improvement
    2. key_risk
    3. implementation_plan
    4. ranking_position
   
```

After this start call, immediately save the returned `jobId` and poll `mcp__claude-review__review_status` with a bounded `waitSeconds` until `done=true`. Treat the completed status payload's `response` as the reviewer output, and save the completed `threadId` for any follow-up round.
5. The Codex executor selects and tests the top 1-2 fusion combinations based on that ranking and available compute

**Normal round — Innovation proposal via reviewer agent:**

```
mcp__claude-review__review_start:
  prompt: |
    [Round N - INNOVATION DESIGN]

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

After this start call, immediately save the returned `jobId` and poll `mcp__claude-review__review_status` with a bounded `waitSeconds` until `done=true`. Treat the completed status payload's `response` as the reviewer output, and save the completed `threadId` for any follow-up round.

**Adversarial Challenge** (same reviewer thread plays devil's advocate on the proposed variants):

After receiving the variant proposals, immediately challenge them in the same thread:

```
mcp__claude-review__review_reply_start:
  threadId: [saved innovation-design agent id]
  prompt: |
    [Round N - ADVERSARIAL CHALLENGE]

    Read the variant proposals in innovation-logs/round-NN/innovation.md.
    Also read src/ to understand the current codebase.

    Play DEVIL'S ADVOCATE on the proposed variants.
    For EACH variant:
    1. FATAL FLAW: strongest reason this will NOT work
    2. HIDDEN ASSUMPTION: what assumption may be wrong
    3. EASIER ALTERNATIVE: simpler route to the same goal
    4. EVALUATION TRAP: how this could produce a misleading improvement
    5. SURVIVAL VERDICT: survive | kill

    Be brutally honest. The goal is to eliminate weak ideas before spending GPU hours.
```

After this start call, immediately save the returned `jobId` and poll `mcp__claude-review__review_status` with a bounded `waitSeconds` until `done=true`. Treat the completed status payload's `response` as the reviewer output, and save the completed `threadId` for any follow-up round.

**Variant selection** (the Codex executor makes the final decision, informed by the adversarial feedback):

Only select from variants that **survived** the adversarial challenge (i.e., NOT killed by a fatal flaw). The Codex executor applies these selection criteria:
1. Does it address the highest-severity root cause?
2. Did it survive GPT-5.4's adversarial critique without a fatal flaw?
3. Is the hypothesis testable with available resources?
4. Does it build on the current best variant, not a dead branch?
5. Is the change small enough to attribute improvement?
6. Does the synergy argument ("1+1>2") make physical/mathematical sense?

If the reviewer killed all variants, request new proposals in the same thread and force it to incorporate the critique:

```
mcp__claude-review__review_reply_start:
  threadId: [saved innovation-design agent id]
  prompt: |
    All proposed variants were killed.
    Propose 2-3 replacements that explicitly avoid the fatal flaws you identified.
    Keep the changes attributable and compatible with the current codebase.
```

After this start call, immediately save the returned `jobId` and poll `mcp__claude-review__review_status` with a bounded `waitSeconds` until `done=true`. Treat the completed status payload's `response` as the reviewer output, and save the completed `threadId` for any follow-up round.

**Collaborative Variant Design** (escalation — see `../shared-references/collaborative-protocol.md`):

If adversarial challenge kills ALL proposed variants for **2 consecutive rounds**, switch from adversarial to collaborative mode:

```
mcp__claude-review__review_reply_start:
  threadId: [saved innovation-design agent id]
  prompt: |
    [COLLABORATIVE MODE - JOINT VARIANT DESIGN]

Read these files directly:
- innovation-logs/EVOLUTION_LOG.md — full history of killed variants and why
- innovation-logs/TECHNIQUE_LIBRARY.md — available techniques
- innovation-logs/BLACKLIST.md — banned approaches
- src/ — current codebase and constraints

    We've hit a wall. All variants were killed for 2 consecutive rounds.
    
    Your recurring objections: [list the main flaws cited across killed variants]
    My implementation evidence: [what the executor observed trying to implement past variants]
    Practical constraints: [what's actually feasible given codebase, data, compute]
    
    Let's design something together instead of the propose-kill cycle.
    
    1. What theoretical property MUST the solution have to avoid your objections?
    2. Given my implementation constraints, what form could that take?
    3. Propose a variant that satisfies BOTH your theoretical concerns
       and my practical constraints.
```

After this start call, immediately save the returned `jobId` and poll `mcp__claude-review__review_status` with a bounded `waitSeconds` until `done=true`. Treat the completed status payload's `response` as the reviewer output, and save the completed `threadId` for any follow-up round.

Then the executor replies with feasibility feedback and continues the thread for up to 6 turns total (see `../shared-references/collaborative-protocol.md`). The jointly-designed variant proceeds to Phase D, then returns to adversarial validation before deployment.

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

After implementing the variant, ALWAYS run an external implementation audit:
```
mcp__claude-review__review_start:
  prompt: |
    IMPLEMENTATION AUDIT

    Variant design:
    [name + hypothesis + intended mechanism]

    Changed files / diff summary:
    [key edits or diff excerpts]

    Review for:
    1. correctness vs design spec
    2. logic bugs
    3. fair baseline comparison
    4. proper seeding and reproducibility
    5. evaluation metric correctness

    Return:
    - verdict: approve | needs-attention
    - critical_issues
    - major_issues
    - minor_issues
```

After this start call, immediately save the returned `jobId` and poll `mcp__claude-review__review_status` with a bounded `waitSeconds` until `done=true`. Treat the completed status payload's `response` as the reviewer output, and save the completed `threadId` for any follow-up round.
- If verdict = `approve` → proceed to Step 1.5
- If verdict = `needs-attention` → apply the shared **Reviewer Resolution Protocol** (see `../shared-references/reviewer-resolution-protocol.md`):
  - Evaluate each finding for correctness
  - Agreed findings → fix
  - Disputed findings → submit rebuttal to the same reviewer thread for adjudication:
    ```
mcp__claude-review__review_reply_start:
  threadId: [saved implementation-audit agent id]
  prompt: |
    Re-check these disputed findings against the actual diff and design spec:
    [disputed items + executor evidence]
    
```

After this start call, immediately save the returned `jobId` and poll `mcp__claude-review__review_status` with a bounded `waitSeconds` until `done=true`. Treat the completed status payload's `response` as the reviewer output, and save the completed `threadId` for any follow-up round.
  - After `CONVERGENCE_MEMO_ROUND` turns on the same issue, append a `Convergence Memo` to `innovation-logs/round-NN/test-gate.md`
  - After `MAX_REVIEW_DISPUTE_ROUNDS`, stop debating and ask for the minimum resolution action only
  - After disputes resolve, fix all confirmed issues and re-run the audit
- **This step is NOT skippable** — every code change must pass external review before deployment

**Step 1.5: Experiment Design + Code Review (Dual Channel)**

Before deploying, run BOTH an independent file-based audit AND a dialogue-based design review:

**Step 1.5a: Independent Code Audit** (fresh reviewer thread focused on fairness and correctness):
```
mcp__claude-review__review_start:
  prompt: |
    INDEPENDENT CODE AUDIT

    Verify this variant implements the stated hypothesis correctly.
    Focus on:
    - baseline fairness (same tuning budget, same data, same compute)
    - logic bugs
    - evaluation using ground truth rather than model outputs
    - fixed seeds and reproducibility

    Variant summary:
    [summary]

    Diff or changed modules:
    [diff summary]
```

After this start call, immediately save the returned `jobId` and poll `mcp__claude-review__review_status` with a bounded `waitSeconds` until `done=true`. Treat the completed status payload's `response` as the reviewer output, and save the completed `threadId` for any follow-up round.

If the audit returns `needs-attention`, apply the shared **Reviewer Resolution Protocol**. Disputed findings should go back through the saved audit thread rather than being hand-waved locally.

**Step 1.5b: Design Review** (fresh reviewer thread reads the design and the code together):

Submit the experiment design for review:

```
mcp__claude-review__review_start:
  prompt: |
    [Round N - EXPERIMENT DESIGN AND CODE REVIEW]

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

After this start call, immediately save the returned `jobId` and poll `mcp__claude-review__review_status` with a bounded `waitSeconds` until `done=true`. Treat the completed status payload's `response` as the reviewer output, and save the completed `threadId` for any follow-up round.

- If issues are found: apply the shared **Reviewer Resolution Protocol**. Confirmed CRITICAL issues must be fixed and re-reviewed; disputed issues must go back through the same saved reviewer thread with concrete executor evidence.
- If reviewer delegation is unavailable: skip review and proceed with self-review only

**Step 1.6: Mandatory Test Gate**

Before any sanity run or deployment, execute the shared **Mandatory Test Gate** from `../shared-references/execution-test-gate.md`.

Requirements:

1. Build a **Change Map** for changed modules, entrypoints, configs, and metrics.
2. Run at least one **module test** per changed module.
3. If no relevant tests exist yet, add the smallest credible module test first.
4. Run one **workflow smoke test** on the smallest real train / eval / inference path for this variant.
5. Record the evidence in `innovation-logs/round-NN/test-gate.md`.

Use this fixed structure:

```markdown
## Mandatory Test Gate
- change map:
- module tests:
- workflow smoke test:
- gate status:

## Convergence Memo
- settled:
- contested:
- unknown:
- minimum resolution path:
```

If the gate fails, stop, fix the implementation, and re-run both the gate and the relevant audit thread.

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

2. **Generate 2-3 loss variants** via the local `claude-review` MCP bridge:
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
5. **Independent verification** (fresh reviewer checks the ablation logic):
   ```
mcp__claude-review__review_start:
  prompt: |
    Read innovation-logs/round-NN/inline-ablation.md and the actual experiment
    output files. Verify:
    1. does the ablation correctly isolate the novel component?
    2. is the causal-vs-confound conclusion supported by the data?
    3. are there methodological issues that invalidate the interpretation?
   
```

After this start call, immediately save the returned `jobId` and poll `mcp__claude-review__review_status` with a bounded `waitSeconds` until `done=true`. Treat the completed status payload's `response` as the reviewer output, and save the completed `threadId` for any follow-up round.
   If the reviewer disagrees with the executor's conclusion, downgrade to `Tied` and log the disagreement.

> This catches confounds DURING optimization, not just at paper-writing time. Skipping this step risks building on a false foundation for 20+ subsequent rounds.

**Step 2.7: Deep Failure Analysis** (only when variant REGRESSED or showed no improvement)

When a variant fails to improve (tied or worse), run a deep failure analysis:

```
mcp__claude-review__review_start:
  prompt: |
    INNOVATION ROUND N FAILURE ANALYSIS

    Read these files directly:
    - innovation-logs/round-NN/results.md
    - innovation-logs/round-NN/innovation.md
    - src/ or the changed modules
    - git diff summary

    Analyze:
    1. implementation_check: was the variant implemented correctly?
    2. integration_check: did the component conflict with the architecture?
    3. root_cause: implementation_bug | integration_conflict | hypothesis_wrong | insufficient_tuning
    4. salvage_plan: concrete revised approach if salvageable
    5. technique_verdict: negative | mixed | retryable
```

After this start call, immediately save the returned `jobId` and poll `mcp__claude-review__review_status` with a bounded `waitSeconds` until `done=true`. Treat the completed status payload's `response` as the reviewer output, and save the completed `threadId` for any follow-up round.

Save to `innovation-logs/round-NN/failure-analysis.md`.

**Route based on reviewer analysis:**
- **Implementation bug** → fix the bug → **re-run Step 1.1 (mandatory external review)** → re-test in the SAME round
- **Integration conflict** → note in TECHNIQUE_LIBRARY how to integrate properly → if fixable now: fix → **mandatory review** → retry; if complex: retry in next round
- **Hypothesis wrong** → mark technique as TESTED-NEGATIVE with specific reason
- **Insufficient tuning** → mark as TESTED-MIXED, suggest hyperparameter range for next attempt
- **Salvageable** → implement revised approach → **mandatory external review** → re-test

> **Rule: ANY code change — including bug fixes from failure analysis — must pass Step 1.1 external review before experiments.**

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

**Step 11: Feishu notification** (if `~/.codex/feishu.json` exists and mode not "off")
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

- **Deep innovation must feed the shared memory layer.** New successful principles, anti-patterns, and revive conditions are not local-only logs; write them back to `research-wiki/` when it exists.

### Execution
- Large file handling: If Write fails due to size, retry with Bash (`cat << 'EOF' > file`) silently — do not ask user for permission
- Always use maximum reasoning depth for diagnosis, design, and failure-analysis reviews
- Each round should use a fresh reviewer call for independent diagnosis; use `send_input` only when continuity materially helps the next review step
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

`deep-innovation-loop` is now part of the default `/research-pipeline` method-evolution stage:

```text
/research-pipeline "robot manipulation"                                           # default: deep innovation gate in auto mode
/research-pipeline "robot manipulation" — deep innovation: true, baseline: DAgger, venue: CoRL, domain: manipulation
/research-pipeline "robot manipulation" — deep innovation: false
```

Behavior:

- `deep innovation: auto` — the pipeline runs an innovation gate after initial experiments and enters `deep-innovation-loop` when structural method evolution is still needed
- `deep innovation: true` — always run `deep-innovation-loop`
- `deep innovation: false` — skip deep innovation and go directly to `/auto-review-loop`

When deep innovation is used, the mainline chain is:

`/idea-discovery` -> implement -> `/deep-innovation-loop` -> `/auto-review-loop` (polish)
