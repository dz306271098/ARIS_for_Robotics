# Codex Context Integrity Protocol

Use this reference whenever interacting with GPT-5.4 via any channel. Ensures GPT-5.4 sees ground truth, not Claude's filtered narrative.

## When to Read

- Read before invoking any `codex exec` command.
- Read before invoking `/codex:adversarial-review` or `/codex:rescue`.
- Read when deciding which tool to use for a given interaction.

## Related References

- `reviewer-independence.md` — Content isolation rules between executor and reviewer
- `reviewer-routing.md` — Dynamic reviewer backend selection (`— reviewer:` parameter)
- `review-tracing.md` — Save full prompt/response pairs for audit and meta-optimize
- `effort-contract.md` — Work intensity levels (lite / balanced / max / beast)

## Three Tools — When to Use Each

ARIS has three tools for GPT-5.4 interaction. Choose based on the task:

| Tool | GPT-5.4 Reads Files? | Best For |
|------|---------------------|----------|
| `codex exec --sandbox read-only -m gpt-5.4` | **Yes** — full repo read access | Structured evaluations (`--output-schema`), visual review (`-i image`), git diff review (`review --base`) |
| `codex exec resume --last` | **Yes** — continues previous session | Multi-turn refinement, follow-up rounds |
| `/codex:rescue --effort xhigh` | **Yes** — autonomously explores | Deep investigation, collaborative sessions, brainstorming |
| `/codex:adversarial-review` | **Yes** — reads git diff + source code | Code review at checkpoints: post-fix validation, pre-deployment audit |

### Decision Tree

```
Need structured evaluation?     → codex exec --output-schema --sandbox read-only -m gpt-5.4 "task"
Need visual review?             → codex exec --sandbox read-only -m gpt-5.4 -i image.pdf "review task"
Need git diff review?           → codex exec review --base main --sandbox read-only -m gpt-5.4
Need multi-turn refinement?     → codex exec resume --last
Need code diff review?          → /codex:adversarial-review --scope working-tree
Need deep investigation?        → /codex:rescue --effort xhigh "task description"
Need design-level challenge?    → /codex:adversarial-review --focus "specific concern"
Need collaborative solving?     → /codex:rescue --effort xhigh "COLLABORATIVE MODE — [context]"
```

### Key Principle

**ALL GPT-5.4 interactions use the three-tool architecture — GPT-5.4 always reads files directly.** No information asymmetry. No selective framing by Claude.

## Prompt Construction Rules

Every `codex exec` command and `/codex:rescue` prompt MUST instruct GPT-5.4 to read project files directly:

```bash
# For codex exec:
codex exec --sandbox read-only -m gpt-5.4 "Read the project files directly. [TASK DESCRIPTION]"

# For codex exec with visual review:
codex exec --sandbox read-only -m gpt-5.4 -i [file.pdf] "Review this [artifact]. Read the project files directly."

# For codex exec with structured output:
codex exec --output-schema '{"score": "number", "issues": "string[]"}' --sandbox read-only -m gpt-5.4 "Evaluate... Read the project files directly."

# For multi-turn follow-up:
codex exec resume --last

# For /codex:rescue:
/codex:rescue --effort xhigh "
[TASK DESCRIPTION]

Read these files directly:
- [list specific files GPT-5.4 should read for this task]
- src/ — source code
- [results files, logs, etc.]

[Additional context from Claude — implementation observations, practical constraints]
"
```

### What to include in the prompt:
1. **Task description** — what GPT-5.4 should do (review, diagnose, propose, evaluate)
2. **"Read the project files directly"** — always include this instruction
3. **Claude's observations** — implementation evidence, practical constraints, what was tried
   - This is supplementary to the files, NOT a replacement
   - Claude's observations help GPT-5.4 understand context that isn't in files (e.g., "this approach failed because the GPU ran out of memory at batch size 32")

## Anti-Framing Self-Check

Before EVERY `codex exec` or `/codex:rescue` call, Claude MUST verify:

- [ ] **All experiments included** — not just successful ones; failed experiments listed with error info
- [ ] **All metrics included** — not just improving ones; regressing metrics explicitly shown
- [ ] **Raw numbers from files** — not rounded, edited, or selectively extracted
- [ ] **Error logs included** — full traceback for any crashed experiments
- [ ] **Previous unaddressed concerns** — reviewer criticisms from prior rounds that remain unfixed
- [ ] **Baseline comparisons complete** — all baselines shown, not just favorable ones

If any item cannot be checked (e.g., no failed experiments this round), explicitly state so in the prompt:
```
[NOTE: No experiments failed this round — all N runs completed successfully]
```

## Mandatory Code Review Rule

**Every code change MUST be reviewed before proceeding.** This is a universal rule across ALL skills:

```
After ANY code modification → /codex:adversarial-review --scope working-tree
```

- **NOT skippable** — no code change enters experiments or next phase without adversarial review
- After review passes, Claude (executor) MUST run the **Post-Coding Verification Protocol** (`post-coding-verification.md`): module test → integration test → regression check
- After receiving review results, Claude (executor) MUST follow the **Review Feedback Verification Protocol** below

## Review Feedback Verification Protocol

**Claude must NOT blindly accept review findings.** After receiving any review feedback (from `codex exec`, `/codex:adversarial-review`, or `/codex:rescue`), Claude must:

### Step 1: Evaluate Each Finding for Correctness

For each finding/weakness, Claude independently assesses:

| Assessment | Action |
|-----------|--------|
| **Agree** — the finding is correct, it is a real issue | Accept and fix |
| **Partially agree** — the finding identifies a real problem, but the suggested fix is inappropriate | Accept the diagnosis, propose a different fix |
| **Disagree** — the finding is incorrect (misread code logic, ignored context, based on wrong assumption) | Proceed to Step 2: Dispute and Discuss |
| **Need more info** — cannot determine if correct | Proceed to Step 2: Request clarification |

### Step 2: Dispute and Discuss (structured multi-turn, bounded)

When Claude disagrees with a finding OR needs more info, it **must NOT silently ignore it, nor blindly comply**. It must:

1. **State Claude's position with evidence** (non-optional — gut-feeling rebuttals are rejected at Step 3):
   - Why is this finding incorrect?
   - Provide specific code/data/logic evidence supporting the rebuttal (cite file:line)

2. **Submit the dispute to the reviewer for adjudication** with a structured output schema:

   ```
   /codex:rescue --effort xhigh "
   [DISPUTE — Round R of 3, Finding ID F<N>]
   
   REVIEWER said: [paste the specific finding verbatim]
   
   EXECUTOR DISAGREES because: [specific reasoning with code/data evidence]
   
   EVIDENCE:
   - file: [path:line] — [what the code actually does]
   - data: [exact number or log excerpt]
   - context: [what reviewer may have missed]
   
   Read these files directly to verify:
   - [relevant source code files]
   - [relevant experiment results]
   
   Adjudicate. Return your response as structured JSON:
   {
     \"verdict\": \"finding_correct\" | \"rebuttal_valid\" | \"compromise_needed\",
     \"evidence\": \"specific files/lines/numbers from your file read\",
     \"reasoning\": \"one-paragraph explanation\",
     \"compromise_proposal\": \"if compromise_needed, specify what both sides should accept; else null\"
   }"
   ```

3. **Handle the adjudication result by verdict**:
   - `finding_correct` → accept and fix. Log as `[DISPUTED R1 → reviewer upheld]`.
   - `rebuttal_valid` → skip this finding. Log as `[DISPUTED R1 → executor rebuttal accepted]` with the reviewer's evidence.
   - `compromise_needed` → if executor agrees with the proposed compromise, implement it. Log as `[DISPUTED R1 → compromise]`. If executor disagrees with the compromise too, proceed to Round 2 (see termination bound).
   - Any malformed response (no JSON, missing fields, contradictory fields) → treat as `finding_correct` (conservative). Log as `[DISPUTED R1 → malformed adjudication, defaulting to reviewer]`.

4. **Termination bound — max 3 adjudication rounds per finding**:
   - If a finding requires more than 3 rounds of dispute, escalate to collaborative mode (see `collaborative-protocol.md`). The 3-round cap prevents infinite ping-pong.
   - If Round 3 still produces `compromise_needed` that executor rejects, log as `[UNRESOLVED DISPUTE — applying conservative fallback]` and apply the reviewer's original finding (conservative default).
   - Rounds 2 and 3 include the prior round's JSON verdict and executor's counter-evidence — not a fresh dispute.

5. **Evidence quality gate**:
   - Rebuttals with no file-path:line citation, no numeric data, or no concrete context are **rejected at Step 2** without submission to adjudication. Log as `[REJECTED REBUTTAL — insufficient evidence, accepting finding]`. This prevents Claude from constructing rebuttals out of plausible-sounding prose.

### Step 3: Log All Review Handling Decisions — mandatory structured output

**File location** (exact path — not optional):
- `auto-review-loop`: `AUTO_REVIEW.md` under `## Round N — Feedback Verification`
- `deep-innovation-loop`: `innovation-logs/round-NN/feedback-verification.md`
- `auto-paper-improvement-loop`: `PAPER_IMPROVEMENT_LOG.md` under `## Round N — Feedback Verification`
- `experiment-bridge`: `refine-logs/round-N-feedback-verification.md`
- `result-to-claim`: `findings.md` under `## Round N — Feedback Verification`

**Schema** — every review finding MUST appear as exactly one row (no missing, no duplicates):

```markdown
## Round N — Feedback Verification — timestamp: ISO-8601

| Finding ID | Finding (verbatim) | Verdict | Dispute Rounds | Action | Reasoning | Evidence cited |
|-----------|---------------------|---------|----------------|--------|-----------|----------------|
| F1 | "Baseline comparison unfair" | Accepted | 0 | Fixed hyperparameter parity | Reviewer was correct | — |
| F2 | "Missing ablation for module X" | Accepted | 0 | Added ablation | Valid concern | — |
| F3 | "Loss function has bug on line 45" | Disputed → Rebuttal accepted (R1) | 1 | No change | Line 45 is intentional design | src/loss.py:45, ablation_round_N.csv |
| F4 | "Statistical test wrong" | Disputed → Compromise (R1) | 1 | Changed from t-test to Wilcoxon | Reviewer's concern about normality valid | scipy.stats test output |
| F5 | "Training unstable" | Rejected rebuttal — insufficient evidence | 0 | Implemented reviewer fix | No file/data citation in rebuttal | — |
| F6 | "Method needs more baselines" | UNRESOLVED DISPUTE — conservative fallback | 3 | Added baselines as reviewer requested | Dispute exhausted 3 rounds, applying default | disputes_F6.json |
```

**Verdict enum** (exactly one value per finding):
- `Accepted` — Step 1 verdict was Agree or Partially agree; fix applied
- `Disputed → Rebuttal accepted (Rn)` — dispute resolved in favor of executor at round n
- `Disputed → Compromise (Rn)` — compromise reached at round n
- `UNRESOLVED DISPUTE — conservative fallback` — 3 rounds exhausted, applying reviewer's finding
- `Rejected rebuttal — insufficient evidence` — Claude tried to dispute but couldn't cite concrete evidence, so finding was accepted without submitting dispute
- `Need more info — resolved` — Step 1 verdict was Need more info; adjudication round clarified; final verdict applied

**Completeness check** (mandatory — enforced at next-phase gate, see "Execution Enforcement Gates" below):
- Every finding from the review JSON output must appear exactly once in the verification table
- No row may have an empty Verdict field
- No row may have empty Reasoning if Verdict ≠ `Accepted`
- A skill proceeding to its next phase WITHOUT producing this file violates the protocol and must halt.

### Key Principles

- **Claude is responsible for verifying review findings** — reviewers can also make mistakes (misread code, ignore context, rely on outdated assumptions)
- **Rebuttals must be evidence-based** — cannot reject findings based on gut feeling alone; must provide code/data/logic evidence
- **Disputes must go through tools** — cannot internally decide a finding is wrong and silently ignore it; must submit to reviewer for adjudication
- **Conservative principle** — when uncertain, lean toward accepting the review finding (the reviewer independently read the files and may have spotted issues Claude missed)
- **Complete logging** — all agreements, rebuttals, discussions, and compromises must be recorded in the review log

This rule is implemented at these checkpoints:

**Primary (after initial implementation):**
- `auto-review-loop` Step C.1.5 — after implementing fixes
- `deep-innovation-loop` Step 1.1 — after implementing variant
- `experiment-bridge` Phase 2.3 — after implementing experiment code

**Secondary (after fix-and-rerun from failure analysis):**
- `result-to-claim` Step 4b — after fixing implementation/integration errors or implementing revised approach
- `idea-creator` Phase 5 step 4 — after fixing pilot code or implementing revised approach
- `deep-innovation-loop` Step 2.7 — after fixing implementation bugs from failure analysis (routes back to Step 1.1)
- `experiment-bridge` Phase 5.7a — after fixing errors from failure investigation (routes back to Phase 2.3)

## Execution Enforcement Gates — HALT-IF-MISSING

Every review-invoking skill MUST include explicit gates that halt execution if review / verification artifacts are missing. This prevents silent skipping.

### Rule 1 — Review-output consumption gate

Every `codex exec --output-schema ... -o /tmp/aris-review-round-N.json` call must be followed by:

```bash
if [ ! -f /tmp/aris-review-round-N.json ] || [ ! -s /tmp/aris-review-round-N.json ]; then
    echo "HALT: Review output missing or empty. Cannot proceed to Phase B/C."
    exit 1
fi
# Also: JSON must parse and contain required top-level keys (verdict, dimensions, blocking_weaknesses)
python3 -c "import json; d=json.load(open('/tmp/aris-review-round-N.json')); assert 'verdict' in d and 'blocking_weaknesses' in d" || { echo "HALT: Review JSON malformed"; exit 1; }
```

Rationale: prevents Phase C from starting while Phase A review is still running, incomplete, or corrupted.

### Rule 2 — Verification-table gate

Every skill that invokes a review MUST produce the verification table (Step 3 schema above) BEFORE any fix implementation begins. The gate is:

```bash
# Example for auto-review-loop before Phase C.1 (fix implementation):
VERIFY_FILE="AUTO_REVIEW.md"
grep -q "## Round $N — Feedback Verification" "$VERIFY_FILE" || { echo "HALT: Feedback Verification table missing for Round $N"; exit 1; }
# Also check: every finding has a non-empty verdict
python3 tools/aris_verify_feedback.py "$VERIFY_FILE" --round "$N" --review-json "/tmp/aris-review-round-$N.json" || exit 1
```

The check verifies:
1. Table section exists in the log file for the current round
2. Every finding from the review JSON appears in the table
3. Every row has a non-empty Verdict in the enum set
4. Every Disputed row has a non-empty Reasoning + Evidence cited

If the check fails, the skill halts with an explicit error pointing to the missing finding ID(s).

### Rule 3 — Dispute output gate

When a dispute is submitted via `/codex:rescue`, the adjudication output MUST be saved as JSON:

```bash
ADJUDICATION_FILE=".aris/disputes/round-${N}-F${FINDING_ID}-round-${DISPUTE_R}.json"
mkdir -p "$(dirname $ADJUDICATION_FILE)"
# (codex rescue writes structured output to this path)
# Gate: verdict field must be one of the 3 valid values
python3 -c "
import json
d = json.load(open('$ADJUDICATION_FILE'))
assert d.get('verdict') in ('finding_correct', 'rebuttal_valid', 'compromise_needed'), 'Invalid verdict'
assert d.get('reasoning'), 'Missing reasoning'
" || { echo "HALT: Malformed dispute adjudication — treating as finding_correct (conservative)"; }
```

If the JSON is malformed, Claude defaults to the conservative interpretation (finding_correct). The dispute is still logged (not silently accepted).

### Rule 4 — Skip detection via trace tracking

Every `codex exec` / `/codex:rescue` / `/codex:adversarial-review` call must write a trace entry:

```bash
bash tools/save_trace.sh --skill "auto-review-loop" --phase "C.1.5" --tool "adversarial-review" --run-id "$N"
```

At the end of each round, a verification script checks that the expected trace entries exist for that round:

```bash
python3 tools/aris_verify_round_traces.py --skill "auto-review-loop" --round "$N" --expected "A.0,A.1,C.1.5,C.5" || echo "WARNING: expected traces missing for Round $N: [list]"
```

This produces an audit trail: if a skill claims "I ran the review" but the trace file doesn't exist, the claim is detected as false.

### Rule 5 — Dispute-budget tracking in state

Every loop skill's state file (`REVIEW_STATE.json`, `INNOVATION_STATE.json`, `PAPER_IMPROVEMENT_STATE.json`) must include:

```json
{
  "round": N,
  "findings": [
    {"id": "F1", "dispute_rounds": 0, "final_verdict": "Accepted"},
    {"id": "F3", "dispute_rounds": 2, "final_verdict": "Disputed → Compromise"},
    {"id": "F6", "dispute_rounds": 3, "final_verdict": "UNRESOLVED DISPUTE — conservative fallback"}
  ]
}
```

This enables cross-round aggregation: if finding F6 keeps appearing and keeps being disputed to exhaustion, it is flagged as "persistently contested" and auto-triggers collaborative escalation in the next round.

### Gate Failure Policy

When any gate fails:
1. **Halt immediately** — do NOT fall back to "proceed anyway" unless the failure is clearly an infrastructure issue (network timeout, disk full).
2. **Log the halt reason** — write to the skill's error log with the specific gate that failed.
3. **Surface to user** — the user sees the halt, not silent degradation.
4. **Infrastructure-failure exception** — if the gate fails because Codex CLI or the file system is unavailable (not because Claude skipped a step), log as `[INFRASTRUCTURE_DEGRADATION]` and apply the skill's documented graceful-degradation path. Do not use infrastructure-failure excuse for "Claude just forgot to run the review."

## When to Escalate to Independent Channel

Switch from `codex exec` to `/codex:adversarial-review` or `/codex:rescue` when:

1. **Every code change** — mandatory adversarial review (see rule above)
2. **Critical checkpoint** — code review before GPU deployment, post-fix validation, result interpretation
3. **Trust verification** — after Claude claims improvement, let GPT-5.4 independently verify from files
4. **Stuck point** — all fix strategies failed, need fresh eyes on the raw data
5. **Ablation verification** — after Claude claims causal contribution confirmed
6. **Final pre-submission audit** — independent review before paper submission

## Integration Points Across Skills

| Skill | Phase | Channel | Purpose |
|-------|-------|---------|---------|
| auto-review-loop | Phase A (pre-review) | `/codex:adversarial-review` | Independent code audit before review round |
| auto-review-loop | Phase C.5 (fix validation) | `/codex:adversarial-review` | Independent verification of fix |
| auto-review-loop | Phase C.6 (stuck) | `/codex:rescue` | Deep investigation when all strategies fail |
| deep-innovation-loop | Phase D Step 1.5 | `/codex:adversarial-review` | Code review — reads actual diff |
| deep-innovation-loop | Phase E Step 2.5 | `/codex:rescue` | Verify ablation conclusion independently |
| deep-innovation-loop | Phase A (plateau) | `/codex:rescue` | Independent diagnosis when stuck 3+ rounds |
| experiment-bridge | Phase 2.5 | `/codex:adversarial-review` | Experiment code audit — baseline fairness, statistical rigor |
| experiment-bridge | Phase 5 | `/codex:rescue` | Independent result interpretation |
| research-review | After Round 3 | `/codex:rescue` | Independent "second opinion" from raw files |
