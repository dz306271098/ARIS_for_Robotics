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

- Critical findings → fix immediately, re-run review
- Medium/low findings → document, proceed
- Approve → proceed
- **NOT skippable** — no code change enters experiments or next phase without adversarial review

This rule is implemented as:
- `auto-review-loop` Step C.1.5
- `deep-innovation-loop` Step 1.1
- `experiment-bridge` Phase 2.3

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
