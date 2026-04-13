---
name: "paper-plan"
description: "Generate a structured paper outline from review conclusions and experiment results. Use when you need to turn evidence into a venue-aware paper plan before drafting."
allowed-tools: Bash(*), Read, Write, Edit, Grep, Glob, Agent, WebSearch, WebFetch
argument-hint: [topic-or-narrative-doc]
---


# Paper Plan: From Review Conclusions to Paper Outline

Generate a structured, section-by-section paper outline from: **$ARGUMENTS**

## Constants

- **REVIEWER_MODEL = `gpt-5.4`** — Used via a secondary Codex reviewer agent for outline review
- **TARGET_VENUE = `ICLR`** — Override as needed
- **MAX_PAGES** — Venue-specific hard budget; for IEEE-style venues, references count too

## Inputs

Use whatever exists in the project:

1. `CLAIMS_FROM_RESULTS.md` — preferred claim source
2. `NARRATIVE_REPORT.md` or `STORY.md`
3. `AUTO_REVIEW.md`, `RESEARCH_REVIEW.md`, rebuttal notes, reviewer findings
4. experiment results, tables, figure-ready JSON/CSV
5. `IDEA_REPORT.md`, `FINAL_METHOD.md`, `CODEX.md`, `RESEARCH_BRIEF.md`

If no narrative file exists, infer the contribution from the available project artifacts and write that inference down before planning the paper.

## Workflow

### Step 1: Extract Claims and Evidence

Build a claims-evidence matrix first. Paper structure comes after this.

Extract:

1. **one-sentence contribution** — the single sentence a reviewer should remember
2. **core claims** — 3-5 claims maximum
3. **evidence per claim** — figures, tables, ablations, proofs, or analysis
4. **known weaknesses** — open risks, weak baselines, scope boundaries
5. **venue-specific framing constraints** — what must be front-loaded

Write:

```markdown
| Claim | Evidence | Status | Risk | Planned Section |
|-------|----------|--------|------|-----------------|
```

If a claim lacks evidence, mark it `needs_experiment` instead of pretending it belongs in the paper.

### Step 2: Choose the Paper Type and Story

Classify the paper before you allocate sections:

- empirical / diagnostic
- method paper
- theory + experiments
- systems / robotics validation

Then apply three story checks:

1. **What** is the contribution?
2. **Why** was the problem hard or unresolved before?
3. **So what** changes because this contribution exists?

If the introduction cannot answer all three early, the story is not ready.

### Step 3: Allocate Venue-Aware Structure

Pick the section count that fits the story. Do not force everything into a rigid template.

For each section, define:

- purpose
- claims carried by the section
- evidence consumed by the section
- expected length
- required citations
- what can move to appendix if space collapses

Also explicitly front-load:

- the one-sentence contribution
- the hero result
- the minimum novelty positioning
- the clearest system or method overview figure

### Step 4: Venue-Specific Notes

For robotics and IEEE-style venues, apply stricter structure checks.

#### RAL / ICRA / IROS style

- include a system overview figure early
- include recent baselines, not just classic ones
- include runtime or latency analysis for real-time claims
- include failure cases or boundary conditions
- remember that page pressure is severe, especially when references count

#### ML conference style

- make the intro self-sufficient
- tie every experiment to a claim
- do not bury the strongest result after the method
- related work must synthesize, not just enumerate

### Step 5: Section-by-Section Planning

For each section, specify a concrete plan:

```markdown
### Abstract
- problem
- why it matters
- approach
- strongest result
- exact takeaway

### Introduction
- opening hook
- gap
- one-sentence contribution
- contributions list
- hero figure description

### Related Work
- 2-4 subclusters
- exact positioning against each cluster

### Method / Setup
- formulation
- design choices
- what is genuinely new

### Experiments
- main table
- ablations
- robustness / failure analysis
- statistical notes

### Conclusion
- concise restatement
- limitations
- future work
```

### Step 6: Figure and Table Plan

List every figure and table with purpose and data source:

```markdown
| ID | Type | Purpose | Data Source | Priority |
|----|------|---------|-------------|----------|
```

For the hero figure, specify:

- what is being compared
- what a skim reader should notice in 3 seconds
- caption draft
- why this figure earns the early placement

### Step 7: Citation Scaffolding

For each section, list required citations and whether they are verified.

Rules:

- never invent citations from memory
- verify authors, venue, and year
- prefer published versions when they exist
- mark uncertain items `[VERIFY]`

### Step 8: External Outline Review

Send the outline to a reviewer agent before freezing it:

```text
spawn_agent:
  model: REVIEWER_MODEL
  reasoning_effort: xhigh
  message: |
    PAPER OUTLINE REVIEW

    Target venue:
    [venue]

    One-sentence contribution:
    [sentence]

    Claims-evidence matrix:
    [matrix]

    Outline:
    [section-by-section plan]

    Figure plan:
    [figures and tables]

    Return:
    1. logical_flow_score: 1-10
    2. claim_evidence_alignment: strong | mixed | weak
    3. missing_sections_or_analysis: ranked list
    4. overclaimed_sections: ranked list
    5. venue_fit_risks: ranked list
    6. page_budget_risks: ranked list
    7. minimum_fixes: concrete edits only
```

Apply the minimum credible fixes before finalizing.

### Step 9: Output

Write `PAPER_PLAN.md` with:

- title placeholder
- one-sentence contribution
- venue and page budget
- paper type
- claims-evidence matrix
- section-by-section structure
- figure plan
- citation plan
- reviewer feedback summary
- next drafting steps

## Key Rules

- The claims-evidence matrix is the backbone. Build it first.
- Be honest about weak evidence; move unsupported material out of the main claim path.
- Front-load the strongest story elements.
- The page budget is hard; decide early what belongs in appendix.
- Leave author metadata as placeholder or anonymous.
