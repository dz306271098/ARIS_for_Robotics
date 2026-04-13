---
name: "novelty-check"
description: "Verify research idea novelty against recent literature. Use when you need a hard answer on whether a method, claim, or experimental framing is genuinely new."
allowed-tools: Bash(*), WebSearch, WebFetch, Grep, Read, Glob, Agent
argument-hint: [method-or-idea-description]
---


# Novelty Check Skill

Check whether a proposed method or claim has already been done in the literature: **$ARGUMENTS**

## Constants

- **REVIEWER_MODEL = `gpt-5.4`** — Used through a secondary Codex reviewer agent
- **MIN_QUERY_VARIANTS = 3** — Minimum search formulations per core claim
- **RECENT_WINDOW_MONTHS = 6** — Always inspect the most recent half-year because concurrent work matters

## Workflow

### Phase A: Extract the Novelty Surface

Turn the method description into 3-5 searchable novelty claims:

1. what the method does
2. what mechanism makes it different
3. what setting or constraint matters
4. what baseline family it claims to beat or replace
5. what result or finding would still be novel even if the method itself is not

Write these claims down before searching. If the claims are fuzzy, the search will be fuzzy too.

### Phase B: Multi-Source Literature Search

For each core claim, search broadly and redundantly.

#### 1. Prefer API tools first

Use reliable project tools before generic web search:

```bash
python3 tools/arxiv_fetch.py search "your query"
python3 tools/semantic_scholar_fetch.py search "your query"
```

Use at least `MIN_QUERY_VARIANTS` query formulations per claim:

- mechanism-focused
- problem-focused
- baseline-relative
- domain-transfer phrasing when relevant

#### 2. Venue-aware search

Always check recent arXiv and venue-specific sources.

- ML-heavy ideas: ICLR, NeurIPS, ICML, ACL, CVPR, AAAI
- Robotics-heavy ideas: RAL, ICRA, IROS, RSS, CoRL, TRO
- Cross-disciplinary ideas: also inspect adjacent venues where the mechanism could have appeared first

For robotics topics, do not stop at "robotics" venues. Many key mechanisms first appear in sequence modeling, sensor fusion, control, or perception venues.

#### 3. Read past titles

For each potentially overlapping paper:

- fetch abstract
- inspect related-work positioning if accessible
- note the precise overlap: mechanism, setting, or claim

If you know the URL, prefer a bounded fetch:

```bash
curl -sL --max-time 30 "URL"
```

### Phase C: Build the Overlap Table

Before asking the reviewer, compile a table like:

```markdown
| Paper | Year | Venue | Overlap | Key Delta | Risk Level |
|------|------|-------|---------|-----------|------------|
```

Also mark:

- exact duplicates
- same mechanism in a different domain
- same setting with a different mechanism
- likely reviewer citations even if not exact duplicates

### Phase D: External Cross-Verification

Use a reviewer agent to challenge the novelty claim against the paper list you found.

```text
spawn_agent:
  model: REVIEWER_MODEL
  reasoning_effort: xhigh
  message: |
    NOVELTY VERDICT

    Proposed method:
    [description]

    Core novelty claims:
    [claim list]

    Candidate prior work:
    [overlap table with paper summaries]

    Return:
    1. overall_novelty: high | medium | low
    2. per_claim_novelty: claim-by-claim verdicts
    3. closest_prior_work: ranked list
    4. exact_overlap_risk: what a skeptical reviewer would cite
    5. genuine_delta: what still looks new after accounting for prior work
    6. positioning_advice: how to frame this honestly
    7. proceed_recommendation: proceed | proceed_with_caution | abandon

    Be brutally honest. "Apply X to Y" is not novel unless the new setting creates a meaningful scientific or technical delta.
```

### Phase E: Write the Novelty Report

Output a structured report to `NOVELTY_CHECK.md`:

```markdown
## Novelty Check Report

### Proposed Method
[1-2 sentence summary]

### Core Claims
1. [Claim] — HIGH / MEDIUM / LOW

### Closest Prior Work
| Paper | Year | Venue | Overlap | Key Delta |

### Overall Verdict
- Score: X/10
- Recommendation: PROCEED / PROCEED WITH CAUTION / ABANDON
- Main novelty risk: [...]
- Honest positioning: [...]
```

If the method is not novel but the **finding**, **evaluation setup**, or **negative result** would still be interesting, say that explicitly. Do not collapse all value into method novelty alone.

## Web Resilience Rules

- Prefer API tools over WebSearch/WebFetch.
- If a web request stalls, abandon it and move on. Novelty checking must degrade gracefully.
- If search coverage is incomplete, mark the report `[PARTIAL SEARCH - VERIFY MANUALLY]`.
- If the web layer is unavailable, still produce a report from reviewer knowledge plus whatever sources you already have.

## Important Rules

- False novelty claims waste months; bias toward skepticism.
- Check both the method and the experimental framing.
- Always search the most recent `RECENT_WINDOW_MONTHS` months for concurrent work.
- A clever reframe is not a substitute for a real delta; only use positioning advice after the overlap is honestly mapped.
