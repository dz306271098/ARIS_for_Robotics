---
name: auto-review-loop
description: Autonomous multi-round research review loop. Repeatedly reviews via Codex MCP, implements fixes, and re-reviews until positive assessment or max rounds reached. Use when user says "auto review loop", "review until it passes", or wants autonomous iterative improvement.
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
- REVIEWER_MODEL = `gpt-5.4` — Model used via Codex MCP. Must be an OpenAI model (e.g., `gpt-5.4`, `o3`, `gpt-4o`)
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

**Step A.0: Independent File Audit** (Codex Plugin — GPT-5.4 reads files directly)

Before compiling the review prompt, run an independent code/experiment audit so GPT-5.4 forms its own view from ground truth:

```
/codex:adversarial-review --scope working-tree --focus "Review current experiment code, results, and method implementation. Check for: unfair baseline comparisons, missing statistical tests, cherry-picked metrics, implementation bugs, overclaimed results"
```

Append the adversarial-review findings to the review context below. Claude CANNOT filter these findings — include them verbatim.

See `../shared-references/codex-context-integrity.md` for channel selection and evidence rules.

**Step A.1: Multi-turn Review** (MCP dialogue — multi-round scoring)

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

For Round 2+, use `codex exec resume --last` to continue the prior session with accumulated context:
```bash
codex exec resume --last --sandbox read-only \
  --output-schema "$SCHEMA_PATH" -o /tmp/aris-review-round-N.json \
  "[Round N update] Since last review: [actions taken]. Read latest files and re-score."
```

#### Phase B: Parse Assessment

Read the structured JSON from `/tmp/aris-review-round-N.json` and extract:
- **Dimension scores** — `dimensions.novelty`, `dimensions.technical_soundness`, etc.
- **Overall score** — `overall_score`
- **Verdict** — `verdict` (READY / ALMOST / NOT_READY)
- **BLOCKING weaknesses** — `blocking_weaknesses[]`
- **STRENGTHENING weaknesses** — `strengthening_weaknesses[]`
- **Action items** (ranked list of fixes, BLOCKING first)

**Review Feedback Verification** (see `../shared-references/codex-context-integrity.md`):

Before implementing ANY fix from the review, Claude must verify each weakness:
- **Blocking weaknesses**: Evaluate each BLOCKING finding — is it truly BLOCKING-level? If Claude believes the reviewer misjudged (e.g., flagging intentional design as a bug), submit a rebuttal via `/codex:rescue` for adjudication.
- **Scoring disputes**: If Claude believes a dimension score is unfair (e.g., reviewer overlooked existing ablation studies), submit specific evidence-based rebuttal.
- Log all agreements/rebuttals/discussions in `AUTO_REVIEW.md` under `## Feedback Verification` for that round.

**STOP CONDITION**: If overall score meets POSITIVE_THRESHOLD for TARGET_VENUE AND no BLOCKING weaknesses remain (after verification) → stop loop, document final state. If verdict contains "ready" → also stop.

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
   a. Search arXiv + Semantic Scholar for techniques addressing this root cause.
      **Web resilience**: Prefer API tools (`python tools/arxiv_fetch.py search "query"`, `python tools/semantic_scholar_fetch.py search "query"`) over WebSearch. If WebSearch/WebFetch hangs (~60s), abandon immediately and continue with available results. Phase B.5 must NEVER block the pipeline.
   b. Look for solutions in adjacent domains (control theory, reinforcement learning, computer vision, motion planning)
   c. **Extract distilled principles** — for each relevant technique found, apply the Principle Extraction Protocol from `../shared-references/principle-extraction.md`:
      - Layer 1: What did the paper specifically do? (surface method)
      - Layer 2: WHY does it work? (underlying principle — one sentence, no paper-specific nouns)
      - Layer 3: How does this generalize beyond the paper's domain? (domain-agnostic formulation)
      - Layer 4: How does this principle re-specialize for OUR problem? (adaptation)
      - Layer 5: What must NOT be copied? (anti-copying guard)
   d. Propose 2-3 fix strategies grounded in the distilled principles, not in transplanted methods:
      - Strategy A: Minimal fix (as reviewer suggested)
      - Strategy B: Novel design inspired by a distilled principle (cite the principle, not the paper's method)
      - Strategy C: Novel design fusing insights from multiple distilled principles
   e. Select the most promising strategy based on:
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

4. **Decision gate**:
   - Fix is significant AND addresses root cause AND passes independent verification → proceed to Phase E (document), then next review round
   - Fix is NOT significant OR doesn't address root cause OR independent review flags critical issues → try next strategy from Phase B.5 (Strategy B or C) before re-review
   - All strategies exhausted without validated improvement → escalate to **Phase C.6 (Collaborative)**

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

After collaborative session:
1. Implement the jointly-designed solution (repeat Phase C steps C.1-C.4)
2. Validate with Phase C.5 (significance + root-cause check)
3. If validated → proceed to Phase E, then next review round
4. If still fails → document as `[COLLABORATIVE IMPASSE]` in AUTO_REVIEW.md, proceed to next round

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
