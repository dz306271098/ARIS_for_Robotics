---
name: idea-creator
description: Generate and rank research ideas given a broad direction. Use when user says "找idea", "brainstorm ideas", "generate research ideas", "what can we work on", or wants to explore a research area for publishable directions.
argument-hint: [research-direction]
allowed-tools: Bash(*), Bash(codex*), Read, Write, Grep, Glob, WebSearch, WebFetch, Agent, Skill(codex:rescue), Skill(codex:adversarial-review)
---

# Research Idea Creator

Generate publishable research ideas for: $ARGUMENTS

## Overview

Given a broad research direction from the user, systematically generate, validate, and rank concrete research ideas. This skill composes with `/research-lit`, `/novelty-check`, and `/research-review` to form a complete idea discovery pipeline.

## Constants

- **PILOT_MAX_HOURS = 2** — Skip any pilot estimated to take > 2 hours per GPU. Flag as "needs manual pilot".
- **PILOT_TIMEOUT_HOURS = 3** — Hard timeout: kill pilots exceeding 3 hours. Collect partial results if available.
- **MAX_PILOT_IDEAS = 3** — Pilot at most 3 ideas in parallel. Additional ideas are validated on paper only.
- **MAX_TOTAL_GPU_HOURS = 8** — Total GPU budget for all pilots combined.
- **REVIEWER_MODEL = `gpt-5.4`** — Model used via Codex CLI for brainstorming and review. Must be an OpenAI model (e.g., `gpt-5.4`, `o3`, `gpt-4o`).

> 💡 Override via argument, e.g., `/idea-creator "topic" — pilot budget: 4h per idea, 20h total`.

## Workflow

### Phase 0: Load Research Wiki (if `research-wiki/` exists)

**Skip entirely if `research-wiki/` directory does not exist.**

If the wiki exists, load it BEFORE landscape survey to avoid repeating known work:

1. Read `research-wiki/query_pack.md` — compressed context (gaps, failed ideas, top papers, principle library, top unresolved failures)
2. **Treat listed gaps as priority search seeds** for Phase 1
3. **Treat failed ideas as banlist** — do NOT regenerate similar ideas
4. **Treat top papers as known prior work** — skip re-searching them
5. **Treat latent-opportunity principles (from AUDIT_REPORT) as ideation seeds** — principles cited by ≥3 papers but never tested in any of OUR projects are high-leverage starting points for novel ideas
6. **Treat OPEN contradictions (from AUDIT_REPORT) as unresolved tensions** — resolving a contradiction is often a publishable contribution in itself
7. **Treat "Top unresolved failures" (from query_pack + AUDIT_REPORT) as the sharpest ideation seeds** — failure patterns with `status=active`, `evidence_papers ≥ 3`, and no known resolution are where "people have repeatedly tried and failed." Ideation focused on these has a much stronger signal than gap-based ideation. For each unresolved failure, brief GPT-5.4 with: "propose a method that, by its mechanism, avoids triggering this failure condition."
8. **Treat failure-clusters (from AUDIT_REPORT analysis d) as meta-targets** — failure patterns spanning many principles point to solution directions larger than any single principle (e.g., "cold-start data scarcity" across multiple learning paradigms → data-centric meta-strategies)

If `query_pack.md` is missing or > 7 days old:
```bash
python3 tools/research_wiki.py rebuild_query_pack research-wiki/
```

If `AUDIT_REPORT.md` is missing or > 24 hours old:
```
/research-wiki audit
```

**First-run graceful degradation**: if `research-wiki/` exists but is **newly initialized** (fewer than 3 papers, principles, or failures), the wiki's seeds (latent-opportunity principles, top unresolved failures, OPEN contradictions) will be empty. This is expected — skip those seed sources silently, do NOT error. Phase 2 brainstorm falls back to literature-only ideation (still works). Over time, as `/research-lit` ingests papers, these sections auto-populate and subsequent idea-creator runs get progressively richer seeds.

**If `research-wiki/` is missing**: skip all wiki-sourced seeds (as Phase 0 already handles). Running `/research-wiki init` is the user's choice — we do not auto-initialize to avoid creating empty project artifacts.

### Phase 1: Landscape Survey (5-10 min)

Map the research area to understand what exists and where the gaps are.

1. **Scan local paper library first**: Check `papers/` and `literature/` in the project directory for existing PDFs. Read first 3 pages of relevant papers to build a baseline understanding before searching online. This avoids re-discovering what the user already knows.

2. **Search recent literature** using WebSearch:
   - Top venues in last 2 years:
     - ML conferences: NeurIPS, ICML, ICLR, ACL, EMNLP, CVPR, etc.
     - Robotics venues (when topic involves robotics, navigation, odometry, SLAM, IMU):
       RAL, ICRA, IROS, TRO, CoRL, RSS, Science Robotics
     - Signal processing venues (when topic involves sensor signals, IMU, time series):
       IEEE TSP, IEEE SPL, ICASSP
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

### Phase 2: Idea Generation — Morphological Seed + Divergent Brainstorm

**Use structured divergence, not free-form brainstorming.** Free-form "generate N ideas" converges on safe variations near the seed prompt. A morphological matrix forces coverage of the idea space and surfaces cells that the LLM would otherwise skip.

Read `shared-references/divergent-techniques.md` for the protocol.

**Step 2a — Build the morphological matrix** (per divergent-techniques.md Operator 2):

```bash
codex exec --sandbox read-only -m gpt-5.4 "You are a senior ML researcher mapping the idea space for this research direction. Read the project files directly.

Research direction: [user's direction]
Landscape map (Phase 1 output): [paste]
Key gaps: [paste]
Latent-opportunity principles (from research-wiki AUDIT_REPORT, if available): [paste]
OPEN contradictions (from AUDIT_REPORT, if available): [paste]

Apply shared-references/divergent-techniques.md Operator 2 (Morphological Matrix). Produce:

Step 1: Identify 3 independent design dimensions that together cover the relevant design choices for this research direction. Name them explicitly. Each has 3-5 levels.

Step 2: Produce the full matrix as a table. For each cell mark: EXPLORED (matches tested literature or our prior work), TRIED-FAILED (matches a failed-idea entry from research-wiki), or UNEXPLORED.

Step 3: From the UNEXPLORED cells, select 5 most promising. For each selected cell, produce a one-sentence idea description AND the principle that emerges from that combination.

Output as markdown: the matrix + 5 cell-based ideas."
```

**Step 2b — Free-form brainstorm seeded by the matrix** (use `codex exec resume --last`):

```bash
codex exec resume --last --sandbox read-only -m gpt-5.4 "Building on the morphological matrix above:

Generate 8-12 additional concrete research ideas. For each idea:
1. One-sentence summary
2. Core hypothesis (what you expect to find and why)
3. Which matrix cell / latent principle it relates to (or why it is outside the matrix)
4. Minimum viable experiment (what is the cheapest way to test this?)
5. Expected contribution type: empirical finding / new method / theoretical result / diagnostic
6. Risk level: LOW / MEDIUM / HIGH
7. Estimated effort: days / weeks / months

Prioritize ideas that are:
- Testable with moderate compute (8x RTX 3090 or less)
- Likely to produce a clear positive OR negative result (both are publishable)
- Not 'apply X to Y' unless the application reveals genuinely surprising insights
- Differentiated from the 10-15 papers in the landscape
- At least 3 ideas should exploit the AUDIT_REPORT latent-opportunity principles or OPEN contradictions (if they exist)

A great idea is one where the answer matters regardless of which way it goes."
```

After Step 2b, the candidate pool = (5 matrix cells + 8–12 freeform) ≈ 13–17 ideas.

### Phase 2.5: Structured Divergence Pass (expand pool to 20–30 ideas)

Apply two divergent operators from `shared-references/divergent-techniques.md` to the Phase 2 pool:

**Pass 2.5a — SCAMPER** (per divergent-techniques.md Operator 1):
For each of the 3 most promising matrix cells, run SCAMPER — each seed idea spawns 2 variants chosen from the 7 SCAMPER outputs (Substitute, Combine, Adapt, Modify, Put-to-other-use, Eliminate, Reverse).

**Pass 2.5b — Cross-Domain Leap** (per divergent-techniques.md Operator 4):
Sample ONE source domain from the rotating pool (log the choice to `IDEA_DIVERGENCE_LOG.md` so future runs rotate). Translate 1 principle from that domain into our problem's vocabulary and produce 1 concrete idea. Explicitly record what you are NOT importing (Anti-Copying Guard from principle-extraction.md Layer 5).

```bash
codex exec resume --last --sandbox read-only -m gpt-5.4 "Apply shared-references/divergent-techniques.md:

1. SCAMPER pass: for each of the 3 most promising matrix cells from Phase 2, pick 2 operators out of (S/C/A/M/P/E/R) and produce 2 structurally different variants per cell. 6 new variants total.

2. Cross-Domain Leap: source domain for this run = [DOMAIN — pick one from the pool in divergent-techniques.md Operator 4 that has not been used in recent IDEA_DIVERGENCE_LOG entries]. Find an analogous phenomenon in [DOMAIN], extract the principle, translate into our problem's vocabulary. Produce 1 concrete idea. State explicitly what you are NOT copying from [DOMAIN].

Total output: 6–8 new ideas. Each must be describable without mentioning [DOMAIN] directly — if you cannot, the translation is incomplete.

Append the used domain to IDEA_DIVERGENCE_LOG.md."
```

After Phase 2.5 the candidate pool is ≈ 20–30 ideas — wide enough that Phase 3 filtering ruthlessly to 4–6 survivors actually discriminates, rather than rubber-stamping everything.

### Phase 3: First-Pass Filtering

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

4. **Failure-cluster risk screen** (only if `research-wiki/failures/` exists, quick version): extract the 1–2 load-bearing principles each candidate idea embodies. Grep `research-wiki/failures/` for failure patterns with `failure_mode_of` edges to those principles AND `status=active`. If any candidate sits squarely in a failure pattern that has manifested in ≥ 3 past ideas/experiments with no resolution, deprioritize — the deep check happens in Phase 4, but high-risk candidates should not consume Phase 3's filter budget if cheaper-looking alternatives are available.

Eliminate ideas that fail any of these. Typically the now-larger pool (20–30 after Phase 2.5) reduces to 4–6.

### Phase 4: Deep Validation (for top ideas)

For each surviving idea, run a deeper evaluation:

1. **Novelty check**: Use the `/novelty-check` workflow (multi-source search + GPT-5.4 cross-verification) for each idea

2. **Critical review with Hypothesis Sparring + Failure-Library Check** — for each surviving idea, force (a) generation of ≥2 alternative explanations for its core claim per `shared-references/hypothesis-sparring.md`, AND (b) a query against the wiki failure library for known failure patterns of the idea's principles.

   ```bash
   codex exec resume --last --sandbox read-only -m gpt-5.4 "Here are our top ideas after filtering. Read the project files directly.
   [paste surviving ideas with novelty check results]
   If research-wiki/ exists, also read research-wiki/failures/ — the cross-project failure-pattern library.

   Apply shared-references/hypothesis-sparring.md AND shared-references/failure-extraction.md to each idea.

   For each idea:

   Step A — Identify the idea's core CLAIM (what the idea would prove if it works).
   Step B — Generate 3 competing explanations for why that claim might actually be wrong or already-explained-by-something-else. Weight each in (0, 0.6). Weights sum to 1.0.
   Step C — For the top-weighted competing explanation, specify the cheapest test that would rule it out (existing literature, quick probe, or small pilot).
   Step D — FAILURE-LIBRARY CHECK. List every principle the idea embodies. For each principle, query research-wiki/failures/ for failure patterns with failure_mode_of edges to that principle. Produce:
   - Table: | principle | known failure patterns | status (active/resolved) | applies to us? (Layer 4 check) |
   - Risk classification:
     * HIGH-RISK: ≥ 2 principles share failure patterns that have co-manifested in ≥ 2 past failed ideas/experiments (from manifested_in_ideas / manifested_in_experiments edges)
     * MEDIUM-RISK: 1 principle has a failure pattern with status=active that applies to us
     * LOW-RISK: failure patterns exist but are resolved by other principles the idea embodies, OR Layer 4 check says failures do not apply
   - For HIGH-RISK ideas: either propose a specific mechanism that breaks the failure trigger, OR recommend downgrading the idea.
   Step E — Devil's advocate questions (traditional):
   - What is the strongest objection a reviewer would raise?
   - What is the most likely failure mode NOT already in the library (novel failure)?
   - How would you rank this for a top-venue submission?

   Finally: which 2-3 ideas would you actually work on, given sparring + failure-library analysis?"
   ```

3. **Combine rankings**: Merge your assessment with GPT-5.4's ranking. Select top 2-3 ideas for pilot experiments. Multiple rejection criteria — any one disqualifies an idea for pilot funding:
   - Sparring surfaces a competing explanation with weight ≥ 0.4 AND no cheap falsifier → flagged "needs pre-pilot literature resolution"
   - Failure-library check classifies the idea HIGH-RISK AND no mechanism proposed to break the failure cluster → flagged "refactor or drop"
   - Both a high-risk sparring alternative AND a high-risk failure cluster → automatic drop (compound evidence against)

4. **Persist risk classifications** to research-wiki (if exists): for each surviving idea, add `manifested_as` edges to the failure patterns the idea is at risk of manifesting (preemptive linking). If the pilot confirms a failure, the edge stays; if the pilot avoids the failure, update the edge with `resolved_by` to the specific principle that broke the trigger.

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

4. **Deep failure analysis for negative pilots** (codex:rescue — for EACH idea with NEGATIVE result):
   ```
   /codex:rescue --effort xhigh "Pilot experiment for idea '[idea title]' produced NEGATIVE results.
   Read these files directly:
   - src/ or pilot scripts — the pilot implementation code
   - Pilot output files (logs, metrics JSON/CSV)
   - IDEA_REPORT.md — the original idea description
   - refine-logs/ — experiment plan if exists
   Analyze:
   1. Was the idea implemented correctly in the pilot? Any bugs, shortcuts, or deviations from the idea?
   2. Was the pilot fair (correct baseline, proper evaluation, enough training)?
   3. Is the negative result due to implementation issues or a fundamental flaw?
   4. If salvageable: propose a revised implementation approach.
   5. If fundamentally flawed: explain why so we don't revisit."
   ```
   - If rescue identifies **implementation error** → fix → **mandatory `/codex:adversarial-review --scope working-tree`** → re-pilot (don't eliminate)
   - If rescue identifies **fundamental flaw** → eliminate with documented reason
   - If rescue proposes **revised approach** → implement the revised approach → **mandatory `/codex:adversarial-review --scope working-tree`** → re-pilot

   > **Rule: ANY code fix before re-piloting must pass adversarial review + Post-Coding Verification Protocol (`../shared-references/post-coding-verification.md`): module test → integration test → regression check.**

5. **Re-rank based on empirical evidence + rescue analysis**: Update the idea ranking. An idea with positive pilot signal jumps ahead. An idea with negative pilot BUT salvageable rescue analysis may stay ranked (with note). An idea confirmed fundamentally flawed is eliminated.

Note: Skip this phase if the ideas are purely theoretical or if no GPU is available. Flag skipped ideas as "needs pilot validation" in the report.

### Phase 6: Output — Ranked Idea Report

Write a structured report to `IDEA_REPORT.md` in the project root:

```markdown
# Research Idea Report

**Direction**: [user's research direction]
**Generated**: [date]
**Ideas evaluated**: X generated → Y survived filtering → Z piloted → W recommended

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
1. Start with Idea 1 (positive pilot signal, lowest risk)
2. Idea 3 as backup (weak signal, may need larger scale to confirm)
3. Idea 2 eliminated by pilot — negative result documented

## Next Steps
- [ ] Scale up Idea 1 to full experiment (multi-seed, full dataset)
- [ ] If confirmed, invoke /auto-review-loop for full iteration
```

### Phase 7: Write Ideas to Research Wiki (if `research-wiki/` exists)

**Skip entirely if `research-wiki/` directory does not exist.**

Write ALL generated ideas (recommended + eliminated) back to the wiki for cross-session memory:

```bash
for each idea (recommended AND eliminated):
    # Create research-wiki/ideas/<id>.md with:
    #   - node_id, stage (proposed/piloted/archived), outcome
    #   - hypothesis, method, pilot results
    #   - based_on: [paper:<slug>, ...]
    #   - target_gaps: [gap:<id>, ...]
    
    # Add edges:
    python3 tools/research_wiki.py add_edge research-wiki/ \
      --from "idea:<id>" --to "paper:<slug>" --type "inspired_by" \
      --evidence "Extends approach from..."
    
    python3 tools/research_wiki.py add_edge research-wiki/ \
      --from "idea:<id>" --to "gap:<gid>" --type "addresses_gap" \
      --evidence "Targets gap..."
done

python3 tools/research_wiki.py rebuild_query_pack research-wiki/
python3 tools/research_wiki.py log research-wiki/ \
  "idea-creator wrote N ideas (M recommended, K eliminated)"
```

> Failed ideas are the most valuable wiki memory — they prevent future re-ideation from repeating dead ends.

## Web Resilience Rules

Web operations (WebSearch, WebFetch) can hang and block the pipeline. Apply strictly:

1. **Prefer API tools over WebSearch**: Use `python tools/arxiv_fetch.py search "query"` and `python tools/semantic_scholar_fetch.py search "query"` instead of WebSearch whenever possible. They are faster and more reliable.
2. **Timeout discipline**: If WebSearch/WebFetch does not respond within ~60 seconds, abandon it immediately. Do NOT retry the same query — reformulate or skip.
3. **Never block the pipeline**: Phase 1 (Landscape Survey) MUST complete even if all web searches fail. Fall back to: local papers → arXiv API → Semantic Scholar API → proceed with whatever information is available.
4. **Batch, don't serialize**: When doing multiple searches, alternate between tools (arXiv API, S2 API, WebSearch). If one hangs, the others likely still work.

## Key Rules

- **Large file handling**: If the Write tool fails due to file size, immediately retry using Bash (`cat << 'EOF' > file`) to write in chunks. Do NOT ask the user for permission — just do it silently.

- The user provides a DIRECTION, not an idea. Your job is to generate the ideas.
- Quantity first, quality second: brainstorm broadly, then filter ruthlessly.
- A good negative result is just as publishable as a positive one. Prioritize ideas where the answer matters regardless of direction.
- Don't fall in love with any idea before validating it. Be willing to kill ideas.
- Always estimate compute cost. An idea that needs 1000 GPU-hours is not actionable for most researchers.
- "Apply X to Y" is the lowest form of research idea. Push for deeper questions.
- Include eliminated ideas in the report — they save future time by documenting dead ends.
- **If the user's direction is too broad** (e.g., "NLP", "computer vision", "reinforcement learning"), **autonomously narrow it** by reading `RESEARCH_BRIEF.md`, `CLAUDE.md`, and any existing project files to infer a specific sub-direction. If enough context exists, proceed with the inferred narrowing and document the decision: `"AUTO-NARROWED: [original broad direction] → [specific sub-direction] based on [context source]"`. Only ask the user to narrow if no project context is available at all AND the direction is a single generic word.

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
