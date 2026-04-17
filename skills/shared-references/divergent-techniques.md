# Divergent Thinking Techniques

Use this reference when an ideation or problem-solving phase needs structured creativity rather than free-form LLM brainstorming. Free-form "generate N ideas" converges on nearby, safe variations; structured operators force coverage of the idea space and produce genuine lateral jumps.

This reference defines five divergent operators as ready-to-splice Codex prompt stanzas. Each operator produces a distinct flavor of novelty. Combine two or three per session for best coverage.

## When to Read

- Read when `/idea-creator` Phase 2 brainstorm needs more structure than "Generate 8–12 ideas".
- Read when `/idea-creator` Phase 2.5 (Structured Divergence Pass) fires.
- Read when `deep-innovation-loop` enters a Leap round (rounds 10, 20, 30) or a Cross-Domain round (every `CROSS_DOMAIN_INTERVAL = 7`).
- Read when `research-refine` Phase 3 reviewer feedback suggests lateral alternatives to the current anchor.
- Read when a reviewer is invoked with `-- reviewer-role: lateral`.

## Why This Exists

LLM free-form brainstorming is **local**: it samples ideas near the seed prompt's attractor. Structured divergent operators add **forcing functions** that pull ideation away from the default distribution:

- SCAMPER forces 7 different mutation types (not the 1–2 an LLM naturally explores).
- Morphological matrices force coverage of a combinatorial grid (not just the 2–3 salient combinations).
- Inversion forces consideration of the opposite hypothesis (not just the one that looks right).
- Cross-domain leap forces borrowing from a distant field (not just the one that shares keywords).
- Constraint relaxation forces questioning what the problem *has* to be (not just what solutions to try).

Each operator is ~15 lines of prompt. Use two or three per session; using all five is usually wasteful.

---

## Operator 1: SCAMPER Probe

**Purpose**: Given a seed idea or method, generate 7 structured mutations. Each mutation explores a distinct transformation type.

**Prompt stanza (splice into a Codex exec call):**

```
For the seed idea: [SEED_IDEA]

Apply each SCAMPER operator and produce one concrete variant per operator (7 total):

S — Substitute: replace one core component with a different mechanism. What if [component X] were replaced by [something qualitatively different]?
C — Combine: merge this idea with another idea or technique we have already tested. Which combination exploits complementary strengths?
A — Adapt: reuse a mechanism from a different problem or domain that solves a similar structural problem. Name the source and the translation.
M — Modify / Magnify / Minify: change a dimension of the idea drastically — 10× larger, 10× smaller, 10× more frequent, 10× simpler.
P — Put to other use: apply this idea to a different goal or metric. What else could this mechanism accomplish besides the original target?
E — Eliminate: remove a component assumed necessary. What if [component Y] is simply not there?
R — Reverse / Rearrange: run the idea backward in time, or in reverse causal direction, or rearrange the processing order.

For each variant, state:
- One-line description
- Which operator it came from
- Why it might work (principle, not mechanism)
- One concrete way to test it cheaply
```

**Quality test**: If two SCAMPER outputs describe the same mechanism, the operator collapsed — reject and re-run that operator with stronger "qualitatively different" framing.

---

## Operator 2: Morphological Matrix

**Purpose**: Enumerate a `[dimension A] × [dimension B] × ...` grid of the idea space and force coverage of cells that free-form brainstorming skips.

**When to use instead of SCAMPER**: when the problem has clear structural dimensions (e.g., representation × supervision × timing) and the goal is to find the best cell combination.

**Prompt stanza:**

```
Build a morphological matrix for the problem: [PROBLEM_STATEMENT]

Step 1 — Identify 3 independent design dimensions that together cover the relevant design choices. Examples:
- Representation type: {discrete, continuous, graph, sequence, field, ...}
- Supervision signal: {label, reward, reconstruction, contrast, self-play, ...}
- Inference timing: {offline, streaming, anytime, event-triggered, ...}
Name your 3 dimensions explicitly. Each dimension should have 3–5 levels.

Step 2 — Produce the full matrix as a table. Mark:
- EXPLORED (matches a tested idea)
- TRIED-FAILED (matches a blacklisted / failed idea — read TECHNIQUE_LIBRARY.md and BLACKLIST.md)
- UNEXPLORED (candidate cell)

Step 3 — Pick the 5 most promising UNEXPLORED cells. For each, produce:
- One-sentence idea description
- Why this cell is interesting (what mechanism would emerge from this combination)
- Cheapest falsifier
```

**Quality test**: If the matrix has fewer than 12 cells total (3 × 4) or more than 60 cells (5 × 5 × 3), re-dimension. Too few = dimensions collapsed; too many = dimensions not independent.

---

## Operator 3: Inversion

**Purpose**: Break the assumption that the current approach direction is correct by forcing consideration of its opposite.

**When to use**: when diagnosis has converged on a single root cause, or when all variants cluster around one design philosophy.

**Prompt stanza:**

```
Current hypothesis: [CURRENT_DIAGNOSIS or CURRENT_DESIGN]

Apply the inversion operator:

1. State the hypothesis as an assertion: "We believe [X] because [reason]."
2. Construct the opposite assertion: "What if NOT [X], because [alternative reason]?"
3. For each of the 3 most load-bearing assumptions inside [X], produce one inverted variant:
   - "What if this variable should go DOWN instead of UP?"
   - "What if we should ADD this component instead of REMOVING it?"
   - "What if the cause is the EFFECT rather than the CAUSE?"
4. For each inverted variant, state:
   - What evidence would you expect to see if it were true?
   - Does any existing evidence actually look more like the inverted hypothesis than the current one?
   - Cheapest test that could distinguish the two

Reject inversions that are trivially false. Keep the ones where evidence is actually ambiguous.
```

**Quality test**: At least one inversion must make you genuinely uncertain. If every inverted variant is obviously wrong, the inversion was shallow — target deeper assumptions.

---

## Operator 4: Cross-Domain Leap

**Purpose**: Import a mechanism or principle from a distant field (not an adjacent field). Distant fields are the ones whose vocabulary does not appear in our literature.

**Rotating source-domain pool (sample ONE per invocation; log to prevent repeats within a single run):**

- Physics (condensed matter, statistical mechanics, fluid dynamics)
- Biology (development, evolution, neural coding, ecology)
- Economics & game theory (mechanism design, auctions, equilibria)
- Signal processing & control theory
- Linguistics (syntax, phonology, pragmatics)
- Materials science (phase transitions, self-assembly)
- Neuroscience (population coding, predictive coding)
- Games & game design (difficulty curves, risk–reward loops)
- Ecology (niche construction, trophic cascades)
- Music / composition (voice leading, counterpoint, rhythm)

**Prompt stanza:**

```
Source domain for this leap: [DOMAIN]

Current problem structure: [abstract 2-sentence description of our problem, stripped of our field's jargon]

Step 1 — Find a phenomenon in [DOMAIN] with the same abstract structure. Name it. Give a 2-sentence description using [DOMAIN]'s native vocabulary.

Step 2 — Identify the principle that makes the [DOMAIN] solution effective. State it in one domain-agnostic sentence (cite principle-extraction.md Layer 3 if unsure).

Step 3 — Translate the principle into our problem's vocabulary. Do not copy the [DOMAIN] mechanism — re-derive a realization of the principle from scratch that fits our data, constraints, and architecture.

Step 4 — State what aspects of the [DOMAIN] solution you are explicitly NOT importing (per principle-extraction.md Layer 5, Anti-Copying Guard).

Step 5 — Produce one concrete method proposal that embodies this principle in our setting. One-page design sketch.
```

**Quality test**: The resulting method should be describable without ever mentioning the source domain. If you cannot explain it without saying "like how [physics phenomenon] works," the translation is incomplete.

---

## Operator 5: Constraint Relaxation

**Purpose**: Question whether the problem's stated constraints are actually mandatory. Many "hard problems" are hard because of a constraint that was accepted without examination.

**When to use**: after patience exhausted on multiple variants, or when all designs fight the same trade-off wall.

**Prompt stanza:**

```
Current problem statement: [PROBLEM_STATEMENT]
Explicit constraints: [C1, C2, C3, ...]
Implicit constraints (you must infer these): [I1, I2, I3, ...]

For each constraint (explicit and implicit):

1. State the constraint precisely.
2. State where it came from (hardware, data, deployment target, benchmark, or "just assumed").
3. Rate how load-bearing it is (1 = easily relaxable, 5 = core to the problem identity).
4. For the 2–3 least load-bearing constraints (rating ≤ 3), state what becomes possible if that constraint is relaxed.
5. For the most load-bearing constraint (rating ≥ 4), state what a relaxed-constraint variant of the problem would look like, and whether any upstream decision could make that relaxation acceptable.

Output: 2–3 relaxed problem formulations, each with:
- Which constraint is relaxed
- What the new solution space looks like
- Whether this relaxation is worth bringing to the user / stakeholder for discussion
```

**Quality test**: If every constraint is rated 4–5, the rater is defending the problem rather than analyzing it. Force at least two constraints to rating ≤ 3.

---

## How to Combine Operators

Typical sequence for a single divergence session (e.g., `/idea-creator` Phase 2.5):

1. **Morphological Matrix** first — establishes the coverage grid and surfaces EXPLORED / UNEXPLORED cells.
2. **SCAMPER** on the 2–3 most promising matrix cells — generates mechanism-level variants.
3. **Cross-Domain Leap** as a final injection — adds one radical option that the matrix could not produce because its dimensions were too field-local.

Use **Inversion** and **Constraint Relaxation** only when stuck (ideation plateaued, or diagnosis converged prematurely). They are escalation operators, not default.

## Integration Points

| Skill | Phase | Which operators |
|-------|-------|-----------------|
| `/idea-creator` | Phase 2 prompt | Morphological Matrix (pre-seed the brainstorm) |
| `/idea-creator` | Phase 2.5 (NEW) | SCAMPER + Cross-Domain Leap (expand pool 8–12 → 20–30) |
| `deep-innovation-loop` | Phase B (rounds 7/14/21/28/35/42) | Cross-Domain Leap (mandatory, source rotates) |
| `deep-innovation-loop` | Phase C Leap rounds (10/20/30) | Cross-Domain Leap + SCAMPER on current best variant |
| `deep-innovation-loop` | Phase C Fusion rounds (5/15/25) | Morphological Matrix (unchanged — this was already implicit) |
| `research-refine` | Phase 2 (after anchor) | Inversion on Research Anchor |
| `research-refine` | Phase 3 (review iterations) | Constraint Relaxation if reviewer flags trade-off walls |
| `/research-review` / `auto-review-loop` | `-- reviewer-role: lateral` | Cross-Domain Leap + Inversion, no scoring |

## Anti-Patterns

| Failure mode | Symptom | Fix |
|--------------|---------|-----|
| Operator collapses to free-form brainstorm | LLM ignores the structure and produces generic ideas | Explicitly require table/grid output; reject prose answers |
| SCAMPER outputs look identical | All 7 variants converge on the same mechanism | Strengthen "qualitatively different" framing; reject and re-prompt |
| Cross-domain leap returns to an adjacent field | Source domain ends up being "a different ML subfield" | Enforce that the source domain's vocabulary does not appear in our last 20 papers |
| Morphological matrix has dependent dimensions | Many cells are identical or nonsensical | Redefine dimensions to be genuinely independent |
| Constraint relaxation discards hard constraints | Produces unrealistic "what if compute were infinite" variants | Force each relaxed formulation to be implementable within 2× current budget |
| Too many operators per session | Output becomes overwhelming and ideas are shallow | Cap at 3 operators per divergence session |
