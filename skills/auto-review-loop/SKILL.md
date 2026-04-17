---
name: auto-review-loop
description: Autonomous multi-round research review loop. Repeatedly reviews via Codex CLI, implements fixes, and re-reviews until positive assessment or max rounds reached. Use when user says "auto review loop", "review until it passes", or wants autonomous iterative improvement.
argument-hint: [topic-or-scope]
allowed-tools: Bash(*), Read, Grep, Glob, Write, Edit, Agent, Skill, Skill(codex:rescue), Skill(codex:adversarial-review)
---

# Auto Review Loop: Autonomous Research Improvement

Autonomously iterate: review → implement fixes → re-review, until the external reviewer gives a positive assessment or MAX_ROUNDS is reached.

## Context: $ARGUMENTS

## Constants

- **MAX_ROUNDS = 4** — Maximum number of review iterations. Override via argument, e.g., `— max rounds: 20`.
- POSITIVE_THRESHOLD — venue-specific (overall score is weighted average of 5 dimensions):
  - RAL/TRO: overall >= 7/10 AND no BLOCKING weaknesses AND Experimental Rigor >= 7
  - ICRA: overall >= 7/10 AND no BLOCKING weaknesses AND Technical Soundness >= 7
  - CVPR/ICCV/ECCV: overall >= 7/10 AND no BLOCKING weaknesses AND Novelty >= 7
  - NeurIPS/ICML/ICLR: overall >= 7/10 AND no BLOCKING weaknesses
  - Default: overall >= 7/10 AND no BLOCKING weaknesses
  Or verdict contains "accept" or "ready for submission"
- REVIEW_DOC: `AUTO_REVIEW.md` in project root (cumulative log)
- REVIEWER_MODEL = `gpt-5.4` — Model used via Codex CLI. Must be an OpenAI model (e.g., `gpt-5.4`, `o3`, `gpt-4o`)
- **HUMAN_CHECKPOINT = false** — When `true`, pause after each round's review (Phase B) and present the score + weaknesses to the user. Wait for user input before proceeding to Phase C. The user can: approve the suggested fixes, provide custom modification instructions, skip specific fixes, or stop the loop early. When `false` (default), the loop runs fully autonomously.
- **COMPACT = false** — When `true`, (1) read `EXPERIMENT_LOG.md` and `findings.md` instead of parsing full logs on session recovery, (2) append key findings to `findings.md` after each round.
- **RESEARCH_DRIVEN_FIX = true** — When `true`, add a Phase B.5 between review parsing and fix implementation: for each critical weakness, classify as symptom vs root cause, search literature, extract distilled principles (see `../shared-references/principle-extraction.md`), and propose 2-3 fix strategies grounded in those principles (not transplanted methods). Select the most promising strategy based on integration elegance, expected improvement, and implementation cost. When `false`, implement the reviewer's suggested minimal fixes directly.

> 💡 Override: `/auto-review-loop "topic" — compact: true, human checkpoint: true`

## State Persistence (Compact Recovery)

Long-running loops may hit the context window limit, triggering automatic compaction. To survive this, persist state to `REVIEW_STATE.json` after each round:

```json
{
  "round": 2,
  "threadId": "019cd392-...",
  "status": "in_progress",
  "last_score": 5.0,
  "last_verdict": "not ready",
  "pending_experiments": ["screen_name_1"],
  "timestamp": "2026-03-13T21:00:00"
}
```

**Write this file at the end of every Phase E** (after documenting the round). Overwrite each time — only the latest state matters.

**On completion** (positive assessment or max rounds), set `"status": "completed"` so future invocations don't accidentally resume a finished loop.

## Workflow

### Initialization

1. **Check for `REVIEW_STATE.json`** in project root:
   - If it does not exist: **fresh start** (normal case, identical to behavior before this feature existed)
   - If it exists AND `status` is `"completed"`: **fresh start** (previous loop finished normally)
   - If it exists AND `status` is `"in_progress"` AND `timestamp` is older than 24 hours: **fresh start** (stale state from a killed/abandoned run — delete the file and start over)
   - If it exists AND `status` is `"in_progress"` AND `timestamp` is within 24 hours: **resume**
     - Read the state file to recover `round`, `threadId`, `last_score`, `pending_experiments`
     - Read `AUTO_REVIEW.md` to restore full context of prior rounds
     - If `pending_experiments` is non-empty, check if they have completed (e.g., check screen sessions)
     - Resume from the next round (round = saved round + 1)
     - Log: "Recovered from context compaction. Resuming at Round N."
2. Read project narrative documents, memory files, and any prior review documents. **When `COMPACT = true` and compact files exist**: read `findings.md` + `EXPERIMENT_LOG.md` instead of full `AUTO_REVIEW.md` and raw logs — saves context window.
3. Read recent experiment results (check output directories, logs)
4. Identify current weaknesses and open TODOs from prior reviews
5. Initialize round counter = 1 (unless recovered from state file)
6. Create/update `AUTO_REVIEW.md` with header and timestamp

### Loop (repeat up to MAX_ROUNDS)

#### Phase A: Review

**Step A.0.0: Hypothesis Sparring (when Round ≥ 2)** — see `../shared-references/hypothesis-sparring.md`.

Fires when the previous round produced a non-passing score AND the loop is entering Round 2 or later. Forces generation of **≥3 competing hypotheses** for why the previous round's fixes did not produce a passing review, before committing to Step A.0's file audit.

Skip entirely on Round 1 (no prior failure to diagnose).

```
/codex:rescue --effort xhigh "
Apply shared-references/hypothesis-sparring.md.

Previous round (Round N-1) applied fixes [summary from AUTO_REVIEW.md Round N-1 Actions Taken] but the reviewer still flagged [BLOCKING weaknesses that remained or were added in Round N-1 review].

Produce ≥3 competing hypotheses for WHY the Round N-1 fixes did not resolve the reviewer's concern. Weights in (0, 0.6) summing to 1.0. For each, specify the cheapest falsifier (check existing logs, re-read AUTO_REVIEW.md Round N-1 details, inspect code diff — prefer zero-compute falsifiers).

Run the cheapest falsifier. Report results. The surviving hypothesis becomes the working framing for this round's Phase B.5 fix strategy design.
"
```

Save to `AUTO_REVIEW.md` under the current round's `## Hypothesis Sparring` heading.

**GATE (non-skippable when Round ≥ 2)**: before Step A.0 proceeds, verify the sparring section exists:
```bash
if [ "$ROUND" -ge 2 ]; then
    grep -q "## Round $ROUND — Hypothesis Sparring" AUTO_REVIEW.md || { echo "HALT: Hypothesis Sparring section missing for Round $ROUND"; exit 1; }
fi
```

**Step A.0: Independent File Audit** (Codex Plugin — GPT-5.4 reads files directly)

Before compiling the review prompt, run an independent code/experiment audit so GPT-5.4 forms its own view from ground truth:

```
/codex:adversarial-review --scope working-tree --focus "Review current experiment code, results, and method implementation. Check for: unfair baseline comparisons, missing statistical tests, cherry-picked metrics, implementation bugs, overclaimed results"
```

Append the adversarial-review findings to the review context below. Claude CANNOT filter these findings — include them verbatim.

See `../shared-references/codex-context-integrity.md` for channel selection and evidence rules.

**Step A.1: Multi-turn Review** (Codex CLI — multi-round scoring)

Use `codex exec` with structured output schema — GPT-5.4 reads project files directly AND returns auto-parseable JSON:

```bash
SCHEMA_PATH=$(find ~/.claude/skills/shared-references/codex-schemas/ -name "review-5dim.schema.json" 2>/dev/null | head -1)
[ -z "$SCHEMA_PATH" ] && SCHEMA_PATH="skills/shared-references/codex-schemas/review-5dim.schema.json"

codex exec --sandbox read-only --output-schema "$SCHEMA_PATH" \
  -o /tmp/aris-review-round-N.json \
  -m gpt-5.4 \
  "[Round N/MAX_ROUNDS of autonomous review loop]

Read these project files directly to form your own assessment:
- AUTO_REVIEW.md — previous review rounds
- All experiment result files (JSON/CSV in results/ or refine-logs/)
- Source code in src/ — model, training, evaluation scripts
- NARRATIVE_REPORT.md or FINAL_PROPOSAL.md — method description
- refine-logs/EXPERIMENT_PLAN.md — experiment plan (if exists)
- git log and git diff — recent changes

Act as a senior reviewer at [TARGET_VENUE].

Score each dimension 1-10 (novelty, technical_soundness, experimental_rigor, clarity, significance).
Compute overall = 0.20*novelty + 0.25*technical_soundness + 0.25*experimental_rigor + 0.15*clarity + 0.15*significance.
List blocking_weaknesses (must fix) and strengthening_weaknesses (nice to have).
Verdict: READY / ALMOST / NOT_READY.

Be brutally honest. Read the actual files — do not rely on any summaries."
```

Read the structured JSON result from `/tmp/aris-review-round-N.json` — auto-parseable scores, verdict, and weakness lists.

For Round 2+, use `codex exec resume --last` to continue the prior session with accumulated context. See the **Round 2+ Template** section below for the full prompt pattern.

#### Phase B: Parse Assessment

Read the structured JSON from `/tmp/aris-review-round-N.json` and extract:
- **Dimension scores** — `dimensions.novelty`, `dimensions.technical_soundness`, etc.
- **Overall score** — `overall_score`
- **Verdict** — `verdict` (READY / ALMOST / NOT_READY)
- **BLOCKING weaknesses** — `blocking_weaknesses[]`
- **STRENGTHENING weaknesses** — `strengthening_weaknesses[]`
- **Action items** (ranked list of fixes, BLOCKING first)

**Review Feedback Verification — MANDATORY, PER-FINDING, GATED** (see `../shared-references/codex-context-integrity.md` Section "Review Feedback Verification Protocol" + "Execution Enforcement Gates").

**This is NOT optional and NOT conditional on "if Claude disagrees."** Every single finding (blocking + strengthening) in `/tmp/aris-review-round-N.json` MUST appear in the verification table. The skill HALTS before Phase C if the table is incomplete or malformed.

**Step 1 — Per-finding evaluation (applies to EVERY finding, not just ones Claude happens to disagree with)**:

For each finding in the review JSON, Claude assigns exactly ONE Step-1 verdict from the enum:
- `Agree` — finding is correct, will be fixed
- `Partially agree` — diagnosis valid, suggested fix inappropriate; will propose alternative fix
- `Disagree` — finding incorrect; must provide file-path:line evidence AND proceed to Step 2 dispute
- `Need more info` — cannot determine; must proceed to Step 2 clarification

**Evidence quality gate** (pre-dispute filter): Claude's `Disagree` verdict REQUIRES concrete evidence (file:line citation + numeric data or log excerpt). Rebuttals lacking evidence are auto-downgraded to `Accepted (rejected rebuttal — insufficient evidence)` without submission to `/codex:rescue`. This prevents gut-feeling disputes from wasting compute.

**Step 2 — Dispute via structured `/codex:rescue`** (only for `Disagree` + `Need more info` with valid evidence):

Use the structured dispute template from `codex-context-integrity.md`. Dispute output MUST return JSON with `verdict ∈ {finding_correct, rebuttal_valid, compromise_needed}`. Up to 3 adjudication rounds per finding; round 3 exhaustion → conservative fallback (accept reviewer). Each dispute round's JSON is saved to `.aris/disputes/round-${N}-F${finding_id}-round-${R}.json`.

**Step 3 — Produce verification table** in `AUTO_REVIEW.md` under `## Round N — Feedback Verification`, following the exact schema in `codex-context-integrity.md` Step 3.

**GATE (non-skippable) — runs before Phase C can start**:

```
1. VERIFICATION_TABLE exists: grep '## Round N — Feedback Verification' AUTO_REVIEW.md → MUST match
2. Every finding in /tmp/aris-review-round-N.json appears exactly once in the table → verify row count
3. Every row has non-empty Verdict in the enum set → verify no empty cells
4. Every 'Disputed' row has matching JSON file in .aris/disputes/ → verify file existence
5. Every 'Disputed' row has non-empty Reasoning and Evidence cited fields

If ANY of the above fails: HALT with explicit error pointing to the missing finding ID(s). Phase C cannot start.
If all pass: proceed to Phase C with a clear per-finding action plan.
```

**STOP CONDITION**: If overall score meets POSITIVE_THRESHOLD for TARGET_VENUE AND no BLOCKING weaknesses remain (after Step 1 + 2 verification — not just based on the raw JSON) → stop loop, document final state. If verdict contains "ready" → also stop.

**Persistence**: write each finding's final state to `REVIEW_STATE.json`:
```json
{
  "round": N,
  "findings": [
    {"id": "F1", "dispute_rounds": 0, "final_verdict": "Accepted"},
    {"id": "F3", "dispute_rounds": 2, "final_verdict": "Disputed → Compromise"}
  ]
}
```

Cross-round aggregation: if the same finding text reappears in Round N+1 AND `dispute_rounds >= 2` in Round N, flag as "persistently contested" and auto-invoke `-- reviewer-role: collaborative` on Round N+1 for that specific finding.

#### Human Checkpoint (if enabled)

**Skip this step entirely if `HUMAN_CHECKPOINT = false`.**

When `HUMAN_CHECKPOINT = true`, present the review results and wait for user input:

```
📋 Round N/MAX_ROUNDS review complete.

Score: X/10 — [verdict]
Top weaknesses:
1. [weakness 1]
2. [weakness 2]
3. [weakness 3]

Suggested fixes:
1. [fix 1]
2. [fix 2]
3. [fix 3]

Options:
- Reply "go" or "continue" → implement all suggested fixes
- Reply with custom instructions → implement your modifications instead
- Reply "skip 2" → skip fix #2, implement the rest
- Reply "stop" → end the loop, document current state
```

Wait for the user's response. Parse their input:
- **Approval** ("go", "continue", "ok", "proceed"): proceed to Phase C with all suggested fixes
- **Custom instructions** (any other text): treat as additional/replacement guidance for Phase C. Merge with reviewer suggestions where appropriate
- **Skip specific fixes** ("skip 1,3"): remove those fixes from the action list
- **Stop** ("stop", "enough", "done"): terminate the loop, jump to Termination

#### Feishu Notification (if configured)

After parsing the score, check if `~/.claude/feishu.json` exists and mode is not `"off"`:
- Send a `review_scored` notification: "Round N: X/10 — [verdict]" with top 3 weaknesses
- If **interactive** mode and verdict is "almost": send as checkpoint, wait for user reply on whether to continue or stop
- If config absent or mode off: skip entirely (no-op)

#### Phase B.5: Research-Driven Fix Design (when RESEARCH_DRIVEN_FIX = true)

**Skip this step entirely if `RESEARCH_DRIVEN_FIX = false`.**

When `RESEARCH_DRIVEN_FIX = true` (default), for each critical weakness identified in Phase B:

1. **Classify**: Is this a surface symptom or a root cause?
   - Symptom: "accuracy is low on sequence X"
   - Root cause: "the model has no mechanism to handle contact state transitions during manipulation"

2. **If root cause is novel** (not addressed in prior rounds):
   a. **Consult research-wiki principle library FIRST** (if `research-wiki/` exists):
      - Read `research-wiki/principles/` — latent-opportunity principles (cited by ≥3 papers, never tested in our projects) and TESTED-POSITIVE principles from other projects.
      - Read `research-wiki/AUDIT_REPORT.md` for OPEN contradictions touching this root cause.
      - If a relevant principle exists in the library, use it directly — skip external search.
   b. If the library lacks coverage, search arXiv + Semantic Scholar for techniques addressing this root cause.
      **Web resilience**: Prefer API tools (`python tools/arxiv_fetch.py search "query"`, `python tools/semantic_scholar_fetch.py search "query"`) over WebSearch. If WebSearch/WebFetch hangs (~60s), abandon immediately and continue with available results. Phase B.5 must NEVER block the pipeline.
   c. Look for solutions in adjacent domains (control theory, reinforcement learning, computer vision, motion planning)
   d. **Extract distilled principles** — for each relevant technique, apply the 5-layer Principle Extraction Protocol from `../shared-references/principle-extraction.md` (surface method → underlying principle → generalization → adaptation → anti-copying guard). If `research-wiki/` exists, persist extracted principles via `/research-wiki upsert_principle`.
   e. Propose 2-3 fix strategies grounded in the distilled principles, not in transplanted methods:
      - Strategy A: Minimal fix (as reviewer suggested)
      - Strategy B: Novel design inspired by a distilled principle (cite the principle, not the paper's method)
      - Strategy C: Novel design fusing insights from multiple distilled principles
   f. Select the most promising strategy based on:
      - Integration elegance with existing method (prefer clean fusion over bolting on)
      - Expected improvement magnitude
      - Implementation cost (prefer quick wins for early rounds, deeper changes for later rounds)
      - Novelty of the resulting design (prefer strategies producing genuinely original contributions)

3. **If root cause was addressed before**: Check what worked/didn't in prior rounds (`AUTO_REVIEW.md`). Don't repeat failed approaches.

4. Proceed to Phase C with the selected strategy (which may be more ambitious than the reviewer's minimal suggestion).

#### Phase C: Implement and Validate Fixes (if not stopping)

**Step C.1: Implement** — for each action item (highest priority first):
- Write/modify experiment scripts, model code, analysis scripts
- Self-review: does implementation match the selected strategy from Phase B.5?

**Step C.1.5: Mandatory Code Review** (every round, after ANY code change):

After completing code changes, ALWAYS run an adversarial review before proceeding:
```
/codex:adversarial-review --scope working-tree --focus "Review code changes for: correctness, logic bugs, fair baseline comparison, proper seeding, evaluation metric accuracy, data leakage risk"
```
- If verdict = `approve` → proceed to Step C.2
- If verdict = `needs-attention` → apply **Review Feedback Verification Protocol** (see `../shared-references/codex-context-integrity.md`):
  - Evaluate each finding for correctness
  - Agreed findings → fix
  - Disputed findings → submit rebuttal via `/codex:rescue` for adjudication
  - After disputes resolved, fix all confirmed issues → re-run adversarial-review
- **This step is NOT skippable** — every code change must pass adversarial review

**Step C.1.7: Post-Coding Verification**

After adversarial review passes, run the **Post-Coding Verification Protocol** (`../shared-references/post-coding-verification.md`). All 3 layers (module test → integration test → regression check) must pass before proceeding. If any fails, fix and re-run C.1.5 + C.1.7. Log results to `AUTO_REVIEW.md`.

**Step C.2: Quick hyperparameter sensitivity** — for the changed component:
- Identify the 2-3 key hyperparameters affected by the fix (e.g., learning rate, loss weight, hidden dimension)
- Test 3 configurations: default, 0.5×, 2× of each key parameter
- Run on smallest dataset (1 seed, reduced epochs) to select best config
- Can run in parallel if multiple GPUs available

**Step C.3: Deploy with multiple seeds**
- Deploy best configuration from C.2 with **>= 3 seeds** for statistical validity
- Monitor remote sessions for completion
- **Training quality check** — if W&B is configured, invoke `/training-check` to verify training health

**Step C.4: Wait and collect**
- Collect results from ALL seeds
- Compute **mean ± std** for all metrics
- If W&B not available, collect from output files/logs directly

Prioritization rules:
- Prefer reframing/analysis over new experiments when both address the concern
- Always implement metric additions (cheap, high impact)
- Skip fixes requiring external data/models not available
- For expensive fixes: run hyperparameter check first (C.2) before committing to full deployment

#### Phase C.5: Fix Validation (before re-review)

**Do NOT proceed to next review round until this validation passes.**

1. **Statistical significance check**: For the main comparison vs previous round:
   - Compute mean ± std across seeds
   - For close comparisons (delta < 2× std): run paired t-test or Wilcoxon
   - If improvement is NOT statistically significant (p >= 0.05): the fix may not be real

2. **Root-cause verification**: Does the fix actually address the diagnosed weakness?
   - If reviewer said "accuracy drops on long sequences" → check if THAT specific metric improved (not just overall mean)
   - If reviewer said "missing ablation for component X" → verify the ablation was added and results are meaningful
   - If the targeted metric did NOT improve despite overall improvement: the fix likely addresses a different issue

3. **Independent verification** (Codex Plugin — GPT-5.4 reads actual changes):
   ```
   /codex:adversarial-review --base HEAD~1 --focus "Verify this fix is correctly implemented, statistically validated, and actually addresses the diagnosed weakness"
   ```
   Append findings. If adversarial-review flags CRITICAL issues Claude missed → the fix fails validation regardless of Claude's assessment.

4. **Decision gate (MANDATORY persistence of verdict — not just in-memory decision)**:

   Write the verdict to `/tmp/aris-fix-validation-round-N.json`:
   ```json
   {
     "round": N,
     "verdict": "PASS" | "FAIL" | "PASS_WITH_FINDINGS",
     "significance": {"p_value": ..., "significant": true|false},
     "addresses_root_cause": true|false,
     "independent_verification": "approve" | "needs-attention",
     "critical_findings": [...]
   }
   ```

   Phase E reads this file BEFORE recording the round as "improvement":
   - `verdict == PASS` → proceed to Phase E (document), then next review round
   - `verdict == FAIL` → try next strategy from Phase B.5 (Strategy B or C) before re-review; reset validation artifacts
   - `verdict == PASS_WITH_FINDINGS` → proceed BUT explicitly log the non-critical findings as "deferred" in AUTO_REVIEW.md; they become high-priority in next round
   - All strategies exhausted without `verdict == PASS` → escalate to **Phase C.5.1 (Failure Archaeology)**, then to Phase C.6

   **Gate for Phase E**: if `/tmp/aris-fix-validation-round-N.json` is missing when Phase E starts, HALT. Phase E cannot record metrics as "improved" without a prior validated PASS verdict.

#### Phase C.5.1: Failure Archaeology (before Collaborative Escalation)

**Fires when**: the same weakness has failed validation for the 2nd time in a row (two consecutive C.5 failures on the same root cause).

**Purpose**: Before invoking Phase C.6's collaborative escalation, query the **wiki failure-pattern library FIRST** (fast, deterministic, cross-project), then fall back to literature search only if the wiki has thin coverage. This prevents C.6 from re-inventing a known dead end AND dominates the external-search fallback when the wiki has coverage.

**Step 1 — Wiki failure-library query (PRIMARY, ~5s)**:

```
If research-wiki/failures/ exists:
    1. Extract the core principle(s) being attempted in this failed fix.
    2. For each principle, grep research-wiki/failures/ for failure patterns with failure_mode_of edges to it.
    3. Filter to patterns with evidence_papers ≥ 3 (well-documented, not single-report anomalies).
    4. Rank by: (evidence_papers count × manifestation count) / resolved_by_count.
    5. For the top-ranked match (if any):
       - Read its resolved_by_principles list — these are our prior art for the fix design.
       - Read its manifested_in_ideas + manifested_in_experiments — these are the projects that already tried and failed.
    6. Determine match score (0-10) based on mechanism similarity (Layer 3 generalized form match).

If match score ≥ 7 AND resolved_by_principles is non-empty:
    → Use resolved_by_principles as fix-strategy candidates for Phase C.6. Skip Step 2. Save match to AUTO_REVIEW.md and proceed to C.6.
If match score ≥ 7 AND resolved_by_principles is empty:
    → This is a KNOWN UNRESOLVED failure pattern. Proceed to C.6 with the explicit framing: "this is an open research problem, not a fixable engineering error." Adjust expectations.
If match score < 7 OR no wiki coverage:
    → Fall back to Step 2 (external literature search).
```

**Step 2 — External literature fallback (SECONDARY, if wiki is thin)**:

Only runs if the wiki query returned no strong match. Keeps the Phase-1 Failure Archaeology as a secondary path.

```
/codex:rescue --effort xhigh "
Apply shared-references/reframing-triggers.md failure-archaeology mindset + shared-references/failure-extraction.md to this repeated failure.

Read:
- AUTO_REVIEW.md — the two failed attempts at this weakness
- Current root cause diagnosis (from Phase B.5)
- Strategy attempts (Strategy A and B from Phase B.5)

Step 1 — Extract the core principle/architecture pattern being attempted.
Step 2 — Search literature (arXiv + Semantic Scholar API tools, NOT WebSearch — we want published failure reports) for papers where the SAME principle or architecture was applied to a SIMILAR problem and failed.
Step 3 — For each prior failure found, apply the failure-extraction.md 5-layer protocol to produce a structured failure record.
Step 4 — Compare against current attempt. Is this a repeat of a known failure mode? If yes, what changed that would make it work this time (be honest — usually nothing)?

Output: FAILURE_ARCHAEOLOGY.md with the pattern, prior failures cited, and a 'prior-failure match score' 0-10.
"
```

**Step 3 — Persist to wiki (NEW — both paths feed this)**:

Whether the pattern came from wiki lookup or external search, the current failure becomes data:

```
If research-wiki/ exists:
    /research-wiki upsert_failure-pattern <slug> — from: idea:<current-idea-id>
    add_edge(idea:<current-idea-id>, failure-pattern:<slug>, "manifested_as")
    If a prior failure was newly identified in Step 2 (external search), also persist:
        /research-wiki upsert_failure-pattern <prior-slug> — from: paper:<citation>
```

The wiki gains a new failure-pattern (or the existing one gains another manifestation) whichever way. Over many projects, the library becomes self-bootstrapping: wiki hits rise, external fallbacks decline.

Save to `AUTO_REVIEW.md` under the current round's `## Failure Archaeology` heading. The output is prepended to Phase C.6's collaborative context as "prior failures matching this exact pattern — design must address these constraints, not re-encounter them."

#### Phase C.6: Collaborative Escalation (when all strategies fail)

**Trigger**: All 2-3 fix strategies from Phase B.5 failed validation in Phase C.5. See `../shared-references/collaborative-protocol.md` for the full protocol.

**Step C.6.0: Independent Ground-Truth Investigation** (Codex Plugin — BEFORE collaborative dialogue)

Let GPT-5.4 independently read ALL project files to form its own understanding of why fixes failed:
```
/codex:rescue --effort xhigh "All fix strategies for weakness [X] have failed. Read the experiment results, code changes (git log), error logs, and AUTO_REVIEW.md directly. Independently diagnose why the fixes didn't work and propose a solution based on ground truth. Do NOT rely on any prior summaries."
```

Append the rescue findings to the collaborative context below.

**Step C.6.1: Collaborative Problem Solving** (Codex Plugin — GPT-5.4 reads files + proposes solution)

GPT-5.4 already has the rescue findings from Step C.6.0. Now ask it to propose a collaborative solution:

```
/codex:rescue --effort xhigh "
[COLLABORATIVE MODE — Joint Problem Solving]

Read these files directly:
- AUTO_REVIEW.md — full review history including all failed fix attempts
- All source code in src/ — current implementation
- All experiment results — what was tried and what failed
- refine-logs/ — experiment plans and proposals

Context from Claude (implementation evidence):
- Root cause diagnosed: [from Phase B.5]
- Strategy A tried: [result, why validation failed]
- Strategy B tried: [result, why validation failed]  
- Strategy C tried: [result, why validation failed]
- Practical constraints discovered: [things not apparent from theory alone]

I need your help — not as a reviewer, but as a collaborator.
1. Based on the files you read, does the root cause diagnosis still hold?
2. What theoretical insight might we both be missing?
3. Propose a NEW approach that accounts for the practical constraints.

Produce a CONCRETE implementation plan (specific code changes, expected outcome).
"
```

Claude evaluates the rescue proposal for feasibility. If adjustments needed, run a second `/codex:rescue` with Claude's feasibility feedback. Max 3 rounds of rescue calls.

**Step C.6.2: Assumption Attack + Problem Reframing (mandatory when collaborative converges)**

If the collaborative session in C.6.1 converges on a jointly-designed solution, run Assumption Attack AND Problem Reframing on the converged proposal BEFORE implementing. This is the last safeguard against comfortable convergence — both models agreed, but both may have been wrong about the same assumption.

```
/codex:rescue --effort xhigh "
Apply shared-references/reframing-triggers.md — both Trigger 1 (Assumption Attack) AND Trigger 2 (Problem Reframing).

Collaborative solution: [paste the jointly-designed solution from C.6.1]
Failure archaeology findings (if any): [paste C.5.1 output]
Review history: [recent rounds from AUTO_REVIEW.md]

Trigger 1 (Assumption Attack):
- Parse the collaborative solution for hidden assumptions
- Rank fragility; invert the most fragile
- Evidence check: does existing evidence lean toward the original or the inversion?

Trigger 2 (Problem Reframing):
- Is the reviewer's flagged weakness even the right thing to fix?
- Should we propose a metric, decomposition, or method-family reframing?
- Recommendation: ADOPT solution | EVALUATE-FIRST with pilot | REJECT collaborative solution + ADOPT reframing

If Trigger 2 recommends ADOPT reframing, the next round starts on the reframed problem, NOT on the collaborative solution.
"
```

Save to `AUTO_REVIEW.md` under `## Assumption-Attack + Reframing Gate` for this round.

After collaborative session + reframing gate:
1. If gate recommends ADOPT solution: implement the jointly-designed solution (repeat Phase C steps C.1-C.4)
2. If gate recommends EVALUATE-FIRST: implement a minimal-cost pilot of the solution, verify basic signal, then decide whether to commit
3. If gate recommends REJECT+reframe: skip C.6 implementation; next round's Phase A starts on the reframed problem (log REFRAMING_DECISION.md)
4. Validate outcomes with Phase C.5 (significance + root-cause check)
5. If validated → proceed to Phase E, then next review round
6. If still fails → document as `[COLLABORATIVE IMPASSE]` in AUTO_REVIEW.md, proceed to next round

Log collaborative dialogue to AUTO_REVIEW.md with `[COLLABORATIVE SESSION]` tag.

> The adversarial review ALWAYS gets the final word — the jointly-designed solution is validated through the normal review cycle in the next round.

#### Phase E: Document Round

Append to `AUTO_REVIEW.md`:

```markdown
## Round N (timestamp)

### Assessment (Summary)
- Score: X/10
- Verdict: [ready/almost/not ready]
- Key criticisms: [bullet list]

### Reviewer Raw Response

<details>
<summary>Click to expand full reviewer response</summary>

[Paste the COMPLETE raw response from the external reviewer here — verbatim, unedited.
This is the authoritative record. Do NOT truncate or paraphrase.]

</details>

### Actions Taken
- [what was implemented/changed]

### Results
- [experiment outcomes, if any]

### Status
- [continuing to round N+1 / stopping]
```

**Write `REVIEW_STATE.json`** with current round, threadId, score, verdict, and any pending experiments.

**Append to `findings.md`** (when `COMPACT = true`): one-line entry per key finding this round:

```markdown
- [Round N] [positive/negative/unexpected]: [one-sentence finding] (metric: X.XX → Y.YY)
```

Increment round counter → back to Phase A.

### Termination

When loop ends (positive assessment or max rounds):

1. Update `REVIEW_STATE.json` with `"status": "completed"`
2. Write final summary to `AUTO_REVIEW.md`
3. Update project notes with conclusions
4. **Write method/pipeline description** to `AUTO_REVIEW.md` under a `## Method Description` section — a concise 1-2 paragraph description of the final method, its architecture, and data flow. This serves as input for `/paper-illustration` in Workflow 3 (so it can generate architecture diagrams automatically).
5. **Generate claims from results** — invoke `/result-to-claim` to convert experiment results from `AUTO_REVIEW.md` into structured paper claims. Output: `CLAIMS_FROM_RESULTS.md`. This bridges Workflow 2 → Workflow 3 so `/paper-plan` can directly use validated claims instead of extracting them from scratch. If `/result-to-claim` is not available, skip silently.
6. If stopped at max rounds without positive assessment:
   - List remaining blockers
   - Estimate effort needed for each
   - Suggest whether to continue manually or pivot
5. **Feishu notification** (if configured): Send `pipeline_done` with final score progression table

## Key Rules

- **Large file handling**: If the Write tool fails due to file size, immediately retry using Bash (`cat << 'EOF' > file`) to write in chunks. Do NOT ask the user for permission — just do it silently.

- ALWAYS use `--effort xhigh` for `/codex:rescue` calls (maximum reasoning depth)
- Each round is a fresh `/codex:rescue` call — GPT-5.4 reads the latest files directly. Context accumulates in AUTO_REVIEW.md.
- **Anti-hallucination citations**: When adding references during fixes, NEVER fabricate BibTeX. Use the same DBLP → CrossRef → `[VERIFY]` chain as `/paper-write`: (1) `curl -s "https://dblp.org/search/publ/api?q=TITLE&format=json"` → get key → `curl -s "https://dblp.org/rec/{key}.bib"`, (2) if not found, `curl -sLH "Accept: application/x-bibtex" "https://doi.org/{doi}"`, (3) if both fail, mark with `% [VERIFY]`. Do NOT generate BibTeX from memory.
- Be honest — include negative results and failed experiments
- Do NOT hide weaknesses to game a positive score
- Implement fixes BEFORE re-reviewing (don't just promise to fix)
- **Exhaust before surrendering** — before marking any reviewer concern as "cannot address": (1) try at least 2 different solution paths, (2) for experiment issues, adjust hyperparameters or try an alternative baseline, (3) for theory issues, provide a weaker version of the result or an alternative argument, (4) only then concede narrowly and bound the damage. Never give up on the first attempt.
- If an experiment takes > 30 minutes, launch it and continue with other fixes while waiting
- Document EVERYTHING — the review log should be self-contained
- Update project notes after each round, not just at the end

## Round 2+ Template

Use `codex exec resume --last` to continue the review session with full context:

```bash
codex exec resume --last --sandbox read-only \
  --output-schema "$SCHEMA_PATH" -o /tmp/aris-review-round-N.json \
  "[Round N update — autonomous review loop]

Read the latest files directly (AUTO_REVIEW.md, experiment results, source code, git diff).

Since last review, we have:
1. [Action 1]: [result]
2. [Action 2]: [result]
3. [Action 3]: [result]

Re-score on the same 5 dimensions. Return structured JSON.
"
```

If `resume --last` fails (session expired), start a fresh `codex exec` with full prompt instead.

## Review Tracing

After each `codex exec` reviewer call, save the trace following `../shared-references/review-tracing.md`. Use `bash tools/save_trace.sh` or write files directly to `.aris/traces/auto-review-loop/<date>_run<NN>/`. Respect the `--- trace:` parameter (default: `full`).
