# Codex Context Integrity Protocol

Use this reference whenever interacting with GPT-5.4 via any channel. Ensures GPT-5.4 sees ground truth, not Claude's filtered narrative.

## When to Read

- Read before invoking any `codex exec` command.
- Read before invoking `/codex:adversarial-review` or `/codex:rescue`.
- Read when deciding which tool to use for a given interaction.

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

### Step 2: Dispute and Discuss (when disagreement or ambiguity exists)

When Claude disagrees with a finding, it **must NOT silently ignore it, nor blindly comply**. It must:

1. **State Claude's position with evidence**:
   - Why is this finding incorrect?
   - Provide specific code/data/logic evidence supporting the rebuttal

2. **Submit the dispute to the reviewer for adjudication**:
   ```
   /codex:rescue --effort xhigh "
   Review feedback dispute:
   
   REVIEWER said: [paste the specific finding]
   
   I (Claude/executor) DISAGREE because: [specific reasoning with code/data evidence]
   
   Read these files directly to verify:
   - [relevant source code files]
   - [relevant experiment results]
   
   Please adjudicate: is the reviewer's finding correct, or is the executor's rebuttal valid?
   Provide your independent assessment with evidence from the files."
   ```

3. **Handle the adjudication result**:
   - Reviewer upholds finding with sufficient evidence → accept and fix
   - Reviewer accepts Claude's rebuttal → skip that finding, log as `[DISPUTED — executor rebuttal accepted]`
   - Both sides have valid points → find a compromise, log as `[DISPUTED — compromise reached]`
   - Cannot reach agreement → log as `[UNRESOLVED DISPUTE]`, apply conservative approach (lean toward the reviewer's position, as the reviewer independently read the files and may have seen issues Claude missed)

### Step 3: Log All Review Handling Decisions

For each finding, log the final disposition:
```markdown
| Finding | Verdict | Action | Reasoning |
|---------|---------|--------|-----------|
| "Baseline comparison unfair" | Accepted | Fixed hyperparameter parity | Reviewer was correct |
| "Missing ablation for module X" | Accepted | Added ablation | Valid concern |
| "Loss function has bug on line 45" | Disputed → Rebuttal accepted | No change | Line 45 is intentional design, not bug |
| "Statistical test wrong" | Disputed → Compromise | Changed from t-test to Wilcoxon | Reviewer's concern about normality valid |
```

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
