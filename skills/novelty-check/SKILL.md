---
name: novelty-check
description: Verify research idea novelty against recent literature. Use when user says "查新", "novelty check", "有没有人做过", "check novelty", or wants to verify a research idea is novel before implementing.
argument-hint: [method-or-idea-description]
allowed-tools: Bash(codex*), WebSearch, WebFetch, Grep, Read, Glob, Skill(codex:rescue), Skill(codex:adversarial-review)
---

# Novelty Check Skill

Check whether a proposed method/idea has already been done in the literature: **$ARGUMENTS**

## Constants

- REVIEWER_MODEL = `gpt-5.4` — Model used via Codex CLI. Must be an OpenAI model (e.g., `gpt-5.4`, `o3`, `gpt-4o`)

## Instructions

Given a method description, systematically verify its novelty:

### Phase A: Extract Key Claims
1. Read the user's method description
2. Identify 3-5 core technical claims that would need to be novel:
   - What is the method?
   - What problem does it solve?
   - What is the mechanism?
   - What makes it different from obvious baselines?

### Phase B: Multi-Source Literature Search
For EACH core claim, search using ALL available sources:

1. **Web Search** (via `WebSearch`):
   - Search arXiv, Google Scholar, Semantic Scholar
   - Use specific technical terms from the claim
   - Try at least 3 different query formulations per claim
   - Include year filters for 2024-2026

2. **Known paper databases**:
   Check venue-appropriate conferences:
   - ML: ICLR 2025/2026, NeurIPS 2025, ICML 2025/2026
   - Robotics (when topic involves robotics/navigation/odometry/IMU/SLAM):
     RAL 2024-2026, ICRA 2024-2026, IROS 2024-2025, CoRL 2024-2025,
     RSS 2024-2025, TRO 2024-2026
   - Recent arXiv preprints (2025-2026)

3. **Read abstracts**: For each potentially overlapping paper, WebFetch its abstract and related work section

### Phase B.5: Failure-Library Cross-Check (if research-wiki/failures/ exists)

A method can be **syntactically novel** (no paper does exactly this) but **semantically a known failure** (papers have tried similar principles and failed). This phase catches the second case before wasting pilot compute.

```
If research-wiki/failures/ exists:
    1. Extract the principles embodied by the proposed method (apply shared-references/principle-extraction.md Layer 2 — no need to persist, just identify).
    2. For each principle, grep research-wiki/failures/ for failure patterns with failure_mode_of edges to that principle.
    3. For each match, apply shared-references/failure-extraction.md Layer 4 (Adaptation check): does the method satisfy the failure's generalized conditions?
    4. If ≥ 1 match applies AND status=active AND resolved_by_principles=[]:
       → Flag as SEMANTICALLY REDUNDANT — "novel on surface, embodies known unresolved failure pattern <slug>"
       → Downgrade novelty score
    5. If matches exist but all are resolved:
       → Document which principles in the method resolve them; use in "Suggested Positioning"
       → Novelty slightly boosted if the method's resolution mechanism is itself novel
    6. If no matches: standard novelty analysis proceeds without failure penalty
```

The output is appended to the Phase D report as a "Failure-Library Cross-Check" section with the matching failure patterns (if any) and their resolution status.

### Phase C: Cross-Model Verification
Call REVIEWER_MODEL via Codex CLI with structured output:
```bash
codex exec --output-schema skills/shared-references/codex-schemas/novelty-verdict.schema.json -o /tmp/aris-novelty.json --sandbox read-only -m gpt-5.4 "Read the project files directly. Cross-verify the novelty of the following proposed method against the papers found.

Proposed method description:
[The proposed method description]

Papers found in Phase B:
[All papers found in Phase B]

Is this method novel? What is the closest prior work? What is the delta?"
```

### Phase D: Novelty Report
Output a structured report:

```markdown
## Novelty Check Report

### Proposed Method
[1-2 sentence description]

### Core Claims
1. [Claim 1] — Novelty: HIGH/MEDIUM/LOW — Closest: [paper]
2. [Claim 2] — Novelty: HIGH/MEDIUM/LOW — Closest: [paper]
...

### Closest Prior Work
| Paper | Year | Venue | Overlap | Key Difference |
|-------|------|-------|---------|----------------|

### Failure-Library Cross-Check (if research-wiki/failures/ exists)
- Matching failure patterns: [list failure-pattern:<slug> with status]
- Semantic novelty impact: [boost / neutral / penalty with reason]

### Overall Novelty Assessment
- Score: X/10
- Recommendation: PROCEED / PROCEED WITH CAUTION / ABANDON / SEMANTICALLY REDUNDANT (new verdict — idea is surface-novel but embodies a known unresolved failure; recommend redesign or abandon)
- Key differentiator: [what makes this unique, if anything]
- Risk: [what a reviewer would cite as prior work; ALSO: failure patterns the method may trigger]

### Suggested Positioning
[How to frame the contribution to maximize novelty perception]
```

### Web Resilience Rules

WebSearch/WebFetch can hang and block the novelty check. Apply strictly:

1. **Prefer API tools**: Use `python tools/arxiv_fetch.py search "query"` and `python tools/semantic_scholar_fetch.py search "query"` as PRIMARY search tools. They are faster and more reliable than WebSearch.
2. **Timeout**: If WebSearch/WebFetch does not respond within ~60 seconds, abandon and move to the next query. Do NOT retry the same query.
3. **For fetching abstracts**: Use `curl -sL --max-time 30 "URL"` instead of WebFetch for known URLs (arXiv abs pages, Semantic Scholar pages).
4. **Never block**: The novelty check MUST produce a report even if some web searches fail. Mark any claims with incomplete search coverage as `[PARTIAL SEARCH — verify manually]`.
5. **Graceful degradation**: If all web searches fail, produce the report based on Codex CLI cross-verification alone (Phase C), and flag: "Web search unavailable — novelty assessment based on reviewer knowledge only, manual verification recommended."

### Important Rules
- Be BRUTALLY honest — false novelty claims waste months of research time
- "Applying X to Y" is NOT novel unless the application reveals surprising insights
- Check both the method AND the experimental setting for novelty
- If the method is not novel but the FINDING would be, say so explicitly
- Always check the most recent 6 months of arXiv — the field moves fast
