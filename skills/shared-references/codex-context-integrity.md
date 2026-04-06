# Codex Context Integrity Protocol

Use this reference whenever interacting with GPT-5.4 via any channel. Ensures GPT-5.4 sees ground truth, not Claude's filtered narrative.

## When to Read

- Read before every `mcp__codex__codex` call (MCP dialogue channel).
- Read before invoking `/codex:adversarial-review` or `/codex:rescue`.
- Read when deciding which channel to use for a given interaction.

## Three Channels — When to Use Each

ARIS has three channels for GPT-5.4 interaction. Choose based on the task:

| Channel | GPT-5.4 Reads Files? | Speed | Best For |
|---------|---------------------|-------|----------|
| `mcp__codex__codex` | **Instructed** — prompt 中指定文件路径，要求 Codex 自行读取 + Claude 补充关键原文 | Fast | Multi-turn dialogue: review rounds, collaborative sessions, brainstorming, iterative refinement |
| `/codex:adversarial-review` | **Yes** — reads git diff + source code directly | Medium | Code/experiment review at checkpoints: Phase 2.5 code review, Phase D review, post-fix validation |
| `/codex:rescue --effort high` | **Yes** — full repo read access, autonomously explores | Slow | Deep independent investigation: failure diagnosis, result interpretation, stuck-point analysis |

### Decision Tree

```
Need multi-turn back-and-forth? → mcp__codex__codex (paste raw evidence)
Need code diff review?          → /codex:adversarial-review --scope working-tree
Need independent investigation? → /codex:rescue --effort high "task description"
Need design-level challenge?    → /codex:adversarial-review --focus "specific concern"
```

### Key Principle

**`mcp__codex__codex` = conversational, Claude controls context.**
**`/codex:adversarial-review` and `/codex:rescue` = independent, GPT-5.4 reads ground truth.**

Use independent channels at CRITICAL CHECKPOINTS to prevent information asymmetry. Use MCP dialogue for fast iteration between checkpoints.

## Mandatory Evidence Rules (for MCP Dialogue Channel)

When using `mcp__codex__codex` / `mcp__codex__codex-reply`:

### Rule 1: Always specify files for Codex to read directly

Every MCP prompt MUST include a `FILES TO READ` block listing the files Codex should read from the project directory:

```
FILES TO READ (read these files directly from the project directory):
- src/model.py — current model implementation
- experiments/eval_results.json — latest experiment results
- innovation-logs/round-05/results.md — this round's results
- AUTO_REVIEW.md — previous review history (last 2 rounds)
- refine-logs/EXPERIMENT_PLAN.md — experiment plan

Read these files yourself to verify the context I provide below.
```

This ensures Codex has direct access to ground truth and can cross-check Claude's narrative.

### Rule 2: Paste critical raw evidence inline as backup

In addition to the file read instructions, Claude MUST also paste the most critical raw content inline (in case Codex cannot read certain files):

1. **Experiment results** — raw metrics table (key numbers)
2. **Code changes** — `git diff` output for the current round
3. **Error logs** — full traceback for any failed experiments

Tag pasted content:
```
[FILE: path/to/file, LINES: N-M]
<actual file content here>
[END FILE]
```

### Rule 3: What CAN be summarized
- Background research context (research direction, prior art overview)
- Method description (if Codex already reviewed it in a prior round via threadId)
- Project setup information (GPU config, dataset locations)

## Anti-Framing Self-Check

Before EVERY `mcp__codex__codex` call, Claude MUST verify:

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

## When to Escalate to Independent Channel

Switch from MCP dialogue to `/codex:adversarial-review` or `/codex:rescue` when:

1. **Critical checkpoint** — code review before GPU deployment, post-fix validation, result interpretation
2. **Trust verification** — after Claude claims improvement, let GPT-5.4 independently verify from files
3. **Stuck point** — all fix strategies failed, need fresh eyes on the raw data
4. **Ablation verification** — after Claude claims causal contribution confirmed
5. **Final pre-submission audit** — independent review before paper submission

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
