---
name: "idea-creator"
description: "Generate and rank research ideas given a broad direction. Use when user says \"找idea\", \"brainstorm ideas\", \"generate research ideas\", \"what can we work on\", or wants to explore a research area for publishable directions."
allowed-tools: Bash(*), Read, Write, Grep, Glob, WebSearch, WebFetch, Agent, mcp__gemini_review__review_start, mcp__gemini_review__review_reply_start, mcp__gemini_review__review_status
argument-hint: [research-direction]
---

> Override for Codex users who want **Gemini CLI**, not a second Codex agent, to act as the reviewer. Install this package **after** `skills/skills-codex/*`.

# Research Idea Creator

Generate publishable research ideas for: $ARGUMENTS

## Overview

Given a broad research direction from the user, systematically generate, validate, and rank concrete research ideas. This skill composes with `/research-lit`, `/novelty-check`, and `/research-review` to form a complete idea discovery pipeline.

## Constants

- **PILOT_MAX_HOURS = 2** — Skip any pilot estimated to take > 2 hours per GPU. Flag as "needs manual pilot".
- **PILOT_TIMEOUT_HOURS = 3** — Hard timeout: kill pilots exceeding 3 hours. Collect partial results if available.
- **MAX_PILOT_IDEAS = 3** — Pilot at most 3 ideas in parallel. Additional ideas are validated on paper only.
- **MAX_TOTAL_GPU_HOURS = 8** — Total GPU budget for all pilots combined.
- **IDEATION_LANES = gap-closing, cross-domain analogy, contradiction-resolution, anti-assumption, failure-reframing** — Default divergent ideation lanes.
- **PORTFOLIO_SIZE = 3** — Keep at least `safe`, `bold`, and `contrarian` routes until novelty/review/cheap pilots narrow them.
- **SHADOW_ROUTE_COUNT = 1** — Preserve one non-mainline route after ranking when the evidence is still ambiguous.
- **REVIEWER_MODEL = `gemini-review`** — Gemini reviewer invoked through the local `gemini-review` MCP bridge. This bridge is CLI-first; set `GEMINI_REVIEW_MODEL` if you need a specific Gemini CLI model override.

> 💡 Override via argument, e.g., `/idea-creator "topic" — pilot budget: 4h per idea, 20h total`.

## Workflow

### Phase 0: Load Research Wiki (if `research-wiki/` exists)

**Skip entirely if `research-wiki/` directory does not exist.**

If the wiki exists, load it BEFORE landscape survey to avoid repeating known work:

1. Read `research-wiki/query_pack.md` — compressed context (gaps, failed ideas, top papers)
2. Read `research-wiki/principle_pack.md` — transferable principles and adaptation hints
3. Read `research-wiki/analogy_pack.md` — cross-domain opportunities
4. Read `research-wiki/failure_pack.md` — anti-repetition memory and revive conditions
5. Treat listed gaps as priority search seeds for Phase 1
6. Treat failed ideas as a banlist unless a revive condition is explicitly satisfied
7. Treat top principles and analogy candidates as ideation fuel, not as copy targets

If `query_pack.md` is missing or obviously stale:

```bash
python3 tools/research_wiki.py rebuild_query_pack research-wiki/
```

### Phase 1: Landscape Survey (5-10 min)

Map the research area to understand what exists and where the gaps are.

1. **Scan local paper library first**: Check `papers/` and `literature/` in the project directory for existing PDFs. Read first 3 pages of relevant papers to build a baseline understanding before searching online. This avoids re-discovering what the user already knows.

2. **Search recent literature** using WebSearch:
   - Top venues in the last 2 years (NeurIPS, ICML, ICLR, ACL, EMNLP, etc.)
   - Recent arXiv preprints (last 6 months)
   - Use 5+ different query formulations
   - Read abstracts and introductions of the top 10-15 papers

2. **Build a landscape map**:
   - Group papers by sub-direction / approach
   - Identify what has been tried and what hasn't
   - Note recurring limitations mentioned in "Future Work" sections
   - Flag any open problems explicitly stated by multiple papers

3. **Identify structural gaps**:
   - Methods that work in domain A but haven't been tried in domain B
   - Contradictory findings between papers (opportunity for resolution)
   - Assumptions that everyone makes but nobody has tested
   - Scaling regimes that haven't been explored
   - Diagnostic questions that nobody has asked

### Phase 2: Multi-Lane Idea Generation

Use a Gemini reviewer via `gemini-review` MCP for deliberate divergent thinking. Do NOT ask for one pooled brainstorm first. Generate ideas lane by lane using `../shared-references/innovation-lanes.md`:

- gap-closing
- cross-domain analogy
- contradiction-resolution
- anti-assumption
- failure-reframing

For each lane, ask for 3-5 ideas with:
- one-sentence summary
- source lane
- core hypothesis
- principle(s) used from `principle_pack.md` or newly synthesized from the literature
- minimum viable experiment
- closest prior work
- main kill criterion
- expected contribution type
- risk level
- estimated effort

Then merge the lanes, de-duplicate idea families, and preserve a portfolio split:
- `safe` — best evidence-backed route
- `bold` — highest-upside route with a credible mechanism
- `contrarian` — route that attacks a dominant assumption or prevailing framing

Save the raw divergent pool before filtering so later loops can revisit killed branches intelligently.

### Phase 3: First-Pass Filtering and Portfolio Merge

For each generated idea, quickly evaluate:

1. **Feasibility check**: Can we actually run this experiment with available resources?
   - Compute requirements (estimate GPU-hours)
   - Data availability
   - Implementation complexity
   - Skip ideas requiring > 1 week of GPU time or unavailable datasets

2. **Novelty quick-check**: For each idea, do 2-3 targeted searches to see if it's already been done. Full `/novelty-check` comes later for survivors.

3. **Impact estimation**: Would a reviewer care about the result?
   - "So what?" test: if the experiment succeeds, does it change how people think?
   - Is the finding actionable or just interesting?

Eliminate ideas that fail any of these. Typically the raw multi-lane pool reduces to 4-6 serious candidates. Preserve the best surviving `safe`, `bold`, and `contrarian` routes in `IDEA_PORTFOLIO.md` even if one route already leads the ranking.

### Phase 4: Deep Validation (for top ideas)

For each surviving idea, run a deeper evaluation:

1. **Novelty check**: Use the `/novelty-check` workflow (multi-source search + Gemini reviewer cross-verification) for each idea

2. **Critical review**: Use Gemini via `mcp__gemini_review__review_reply_start` with the saved completed `threadId`:
   ```
   Here are our top ideas after filtering:
   [paste surviving ideas with novelty check results]

   For each, play devil's advocate:
   - What's the strongest objection a reviewer would raise?
   - What's the most likely failure mode?
   - How would you rank these for a top venue submission?
   - Which 2-3 would you actually work on?
   ```

3. **Combine rankings**: Merge your assessment with the Gemini reviewer's ranking. Select top 2-3 ideas for pilot experiments.

### Phase 5: Parallel Pilot Experiments (for top 2-3 ideas)

Before committing to a full research effort, run cheap pilot experiments to get empirical signal. This is the key differentiator from paper-only validation.

1. **Design pilots**: For each top idea, define the minimal experiment that would give a positive or negative signal:
   - Single seed, small scale (e.g., small dataset subset, fewer epochs)
   - Target: 30 min - PILOT_MAX_HOURS per pilot on 1 GPU
   - **Estimate GPU-hours BEFORE launching.** If estimated time > PILOT_MAX_HOURS, reduce scale (fewer epochs, smaller subset) or flag as "needs manual pilot"
   - Clear success metric defined upfront (e.g., "if metric improves by > 1%, signal is positive")

2. **Deploy in parallel**: Use `/run-experiment` to launch pilots on different GPUs simultaneously:
   ```
   GPU 0: Pilot for Idea 1
   GPU 1: Pilot for Idea 2
   GPU 2: Pilot for Idea 3
   ```
   Use `run_in_background: true` to launch all at once.

3. **Collect results**: Use `/monitor-experiment` to check progress. If any pilot exceeds PILOT_TIMEOUT_HOURS, kill it and collect partial results. Once all pilots complete (or timeout), compare:
   - Which ideas showed positive signal?
   - Which showed null/negative results? (eliminate or deprioritize)
   - Any surprising findings that suggest a pivot?
   - Total GPU-hours consumed (track against MAX_TOTAL_GPU_HOURS budget)

4. **Re-rank based on empirical evidence**: Update the idea ranking using pilot results. An idea with strong pilot signal jumps ahead of a theoretically appealing but untested idea.

Note: Skip this phase if the ideas are purely theoretical or if no GPU is available. Flag skipped ideas as "needs pilot validation" in the report.

### Phase 6: Output — Ranked Idea Report and Portfolio

Write a structured report to `IDEA_REPORT.md` in the project root and a branch-aware `IDEA_PORTFOLIO.md` alongside it:

```markdown
# Research Idea Report

**Direction**: [user's research direction]
**Generated**: [date]
**Ideas evaluated**: X generated across lanes → Y survived filtering → Z piloted → W retained in portfolio

## Landscape Summary
[3-5 paragraphs on the current state of the field]

## Recommended Ideas (ranked)

### Idea 1: [title]
- **Hypothesis**: [one sentence]
- **Minimum experiment**: [concrete description]
- **Expected outcome**: [what success/failure looks like]
- **Novelty**: X/10 — closest work: [paper]
- **Feasibility**: [compute, data, implementation estimates]
- **Risk**: LOW/MEDIUM/HIGH
- **Contribution type**: empirical / method / theory / diagnostic
- **Pilot result**: [POSITIVE: metric +X% / NEGATIVE: no signal / SKIPPED: needs GPU]
- **Reviewer's likely objection**: [strongest counterargument]
- **Why we should do this**: [1-2 sentences]

### Idea 2: [title]
...

## Eliminated Ideas (for reference)
| Idea | Reason eliminated |
|------|-------------------|
| ... | Already done by [paper] |
| ... | Requires > 1 week GPU time |
| ... | Result wouldn't be interesting either way |

## Pilot Experiment Results
| Idea | GPU | Time | Key Metric | Signal |
|------|-----|------|------------|--------|
| Idea 1 | GPU 0 | 45 min | +2.3% CE | POSITIVE |
| Idea 2 | GPU 1 | 30 min | -0.1% CE | NEGATIVE |
| Idea 3 | GPU 2 | 1.5 hr | +0.8% CE | WEAK POSITIVE |

## Suggested Execution Order
1. Mainline route: [best evidence-backed route]
2. Shadow route: [bold or contrarian route that still survives]
3. Eliminated routes: [documented with kill reasons]

## Next Steps
- [ ] Scale up Idea 1 to full experiment (multi-seed, full dataset)
- [ ] If confirmed, invoke /auto-review-loop for full iteration
```

### Phase 7: Write Ideas to Research Wiki (if `research-wiki/` exists)

**Skip entirely if `research-wiki/` directory does not exist.**

Write **all** generated ideas back to the wiki, not just the final recommendation. Also persist the principle lineage so later loops can reuse the idea logic without regenerating it from scratch:

```bash
for each idea (recommended AND eliminated):
    # Create or update research-wiki/ideas/<id>.md with:
    #   - node_id, stage, outcome
    #   - hypothesis, method sketch, pilot result
    #   - based_on papers and target gaps

    python3 tools/research_wiki.py add_edge research-wiki/ \
      --from "idea:<id>" --to "paper:<slug>" --type "inspired_by" \
      --evidence "Idea builds on or reacts to this paper"

    python3 tools/research_wiki.py add_edge research-wiki/ \
      --from "idea:<id>" --to "gap:<gid>" --type "addresses_gap" \
      --evidence "Idea explicitly targets this gap"

    python3 tools/research_wiki.py add_edge research-wiki/ \
      --from "idea:<id>" --to "principle:<pid>" --type "applies_principle" \
      --evidence "Idea instantiates this distilled principle"
done

python3 tools/research_wiki.py rebuild_packs research-wiki/
python3 tools/research_wiki.py log research-wiki/ \
  "idea-creator wrote N ideas (recommended + eliminated)"
```

Failed ideas are the most valuable wiki memory because they prevent future re-ideation from looping back into the same dead ends.

## Key Rules

- **Large file handling**: If the Write tool fails due to file size, immediately retry using Bash (`cat << 'EOF' > file`) to write in chunks. Do NOT ask the user for permission — just do it silently.

- The user provides a DIRECTION, not an idea. Your job is to generate the ideas.
- Quantity first, quality second: brainstorm broadly, then filter ruthlessly.
- A good negative result is just as publishable as a positive one. Prioritize ideas where the answer matters regardless of direction.
- Don't fall in love with any idea before validating it. Be willing to kill ideas.
- Always estimate compute cost. An idea that needs 1000 GPU-hours is not actionable for most researchers.
- "Apply X to Y" is the lowest form of research idea. Push for deeper questions.
- Include eliminated ideas in the report — they save future time by documenting dead ends.
- **If the user's direction is too broad (e.g., "NLP", "computer vision", "reinforcement learning"), STOP and ask them to narrow it.** A good direction is 1-2 sentences specifying the problem, domain, and constraint — e.g., "factorized gap in discrete diffusion LMs" or "sample efficiency of offline RL with image observations". Without sufficient specificity, generated ideas will be too vague to run experiments on.

## Composing with Other Skills

After this skill produces the ranked report:
```
/idea-creator "direction"     → ranked ideas
/novelty-check "top idea"     → deep novelty verification (already done in Phase 4, but user can re-run)
/research-review "top idea"   → external critical feedback
implement                     → write code
/run-experiment               → deploy to GPU
/auto-review-loop             → iterate until submission-ready
```
