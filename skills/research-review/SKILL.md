---
name: research-review
description: Get a deep critical review of research from GPT via Codex MCP. Use when user says "review my research", "help me review", "get external review", or wants critical feedback on research ideas, papers, or experimental results.
argument-hint: [topic-or-scope]
allowed-tools: Bash(*), Read, Grep, Glob, Write, Edit, Agent, Skill(codex:rescue), Skill(codex:adversarial-review)
---

# Research Review via Codex MCP (xhigh reasoning)

Get a multi-round critical review of research work from an external LLM with maximum reasoning depth.

## Constants

- REVIEWER_MODEL = `gpt-5.4` — Model used via Codex MCP. Must be an OpenAI model (e.g., `gpt-5.4`, `o3`, `gpt-4o`)

## Context: $ARGUMENTS

## Prerequisites

- **Codex Plugin** installed (provides `/codex:rescue` and `/codex:adversarial-review` — GPT-5.4 reads project files directly)

## Workflow

### Step 1: Gather Research Context
Before calling the external reviewer, compile a list of key project files GPT-5.4 should read.

### Step 2: Initial Review (Round 1)
Use Codex Plugin — GPT-5.4 reads all project files directly:

```
/codex:rescue --effort xhigh "
Read these project files directly to form your assessment:
- NARRATIVE_REPORT.md or paper draft (main.tex, sections/)
- All experiment results (JSON/CSV in results/ or refine-logs/)
- Source code in src/ — model, training, evaluation
- EXPERIMENT_PLAN.md — if exists
- Any prior review documents (AUTO_REVIEW.md)

Act as a senior ML reviewer (NeurIPS/ICML level). Identify:
1. Logical gaps or unjustified claims
2. Missing experiments that would strengthen the story
3. Narrative weaknesses
4. Whether the contribution is sufficient for a top venue
Be brutally honest.
"
```

### Step 3: Iterative Dialogue (Rounds 2-N)
Each round uses a fresh `/codex:rescue` call — GPT-5.4 reads the latest project state directly:

For each round:
1. **Respond** to criticisms with evidence/counterarguments
2. **Ask targeted follow-ups** on the most actionable points
3. **Request specific deliverables**: experiment designs, paper outlines, claims matrices

Key follow-up patterns:
- "If we reframe X as Y, does that change your assessment?"
- "What's the minimum experiment to satisfy concern Z?"
- "Please design the minimal additional experiment package (highest acceptance lift per GPU week)"
- "Please write a mock NeurIPS/ICML review with scores"
- "Give me a results-to-claims matrix for possible experimental outcomes"

### Step 4: Convergence (Adversarial → Collaborative transition)

**Independent File-Based Audit** (after round 3, before agreement checkpoint):

See `../shared-references/codex-context-integrity.md` for protocol.

Before Claude compiles the agreement checkpoint, let GPT-5.4 form its own independent view from the raw project files:
```
/codex:rescue --effort xhigh "Read all project files: NARRATIVE_REPORT.md (or paper draft), experiment results, source code, EXPERIMENT_PLAN.md, and any review documents. Provide an independent critical review WITHOUT relying on any prior review dialogue. Score on 5 dimensions (Novelty, Technical Soundness, Experimental Rigor, Clarity, Significance). List specific weaknesses with file paths and evidence."
```

Append rescue findings to the agreement checkpoint below. This ensures the checkpoint reflects ground truth, not just the MCP dialogue narrative.

**Agreement Checkpoint** (after round 3): Pause and explicitly list:
- What both Claude and GPT-5.4 **agree** on (settled claims, validated evidence)
- What remains **contested** (disagreements on methodology, scope, claims)
- What is **unknown** (needs experiments to resolve)

If contested items remain after 5 turns: switch to **Collaborative Compromise Mode** (see `../shared-references/collaborative-protocol.md`):
- Frame each disagreement as: "GPT believes X because [theory]. Claude believes Y because [implementation evidence]."
- Jointly design a resolution: "What experiment or analysis would settle this disagreement?"
- Produce a **joint deliverable**: experiment roadmap co-designed by both, with each contested item mapped to a specific experiment

Stop iterating when:
- Both sides agree on the core claims and their evidence requirements
- A concrete experiment plan is established (jointly designed, not one-sided)
- The narrative structure is settled
- All contested items have a resolution path (experiment, analysis, or agreed compromise)

### Step 5: Document Everything
Save the full interaction and conclusions to a review document in the project root:
- Round-by-round summary of criticisms and responses
- Final consensus on claims, narrative, and experiments
- Claims matrix (what claims are allowed under each possible outcome)
- Prioritized TODO list with estimated compute costs
- Paper outline if discussed

Update project memory/notes with key review conclusions.

## Key Rules

- ALWAYS use `config: {"model_reasoning_effort": "xhigh"}` for reviews
- Send comprehensive context in Round 1 — the external model cannot read your files
- Be honest about weaknesses — hiding them leads to worse feedback
- Push back on criticisms you disagree with, but accept valid ones
- Focus on ACTIONABLE feedback — "what experiment would fix this?"
- Document the threadId for potential future resumption
- The review document should be self-contained (readable without the conversation)

## Prompt Templates

### For initial review:
"I'm going to present a complete ML research project for your critical review. Please act as a senior ML reviewer (NeurIPS/ICML level)..."

### For experiment design:
"Please design the minimal additional experiment package that gives the highest acceptance lift per GPU week. Our compute: [describe]. Be very specific about configurations."

### For paper structure:
"Please turn this into a concrete paper outline with section-by-section claims and figure plan."

### For claims matrix:
"Please give me a results-to-claims matrix: what claim is allowed under each possible outcome of experiments X and Y?"

### For mock review:
"Please write a mock NeurIPS review with: Summary, Strengths, Weaknesses, Questions for Authors, Score, Confidence, and What Would Move Toward Accept."

## Review Tracing

After each `codex exec` reviewer call, save the trace following `../shared-references/review-tracing.md`. Use `bash tools/save_trace.sh` or write files directly to `.aris/traces/research-review/<date>_run<NN>/`. Respect the `--- trace:` parameter (default: `full`).
