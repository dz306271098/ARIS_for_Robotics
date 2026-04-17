# Hypothesis Sparring Protocol

Use this reference when a diagnosis step is about to commit to a single root cause. Sparring forces generation of **at least three competing hypotheses with explicit probability weights**, and tests the cheapest falsifier first. This prevents premature convergence on the first plausible explanation.

## When to Read

- Read at the start of every `deep-innovation-loop` Phase A (Step 0.5, NEW).
- Read in `auto-review-loop` Phase A when `patience_counter ≥ 2` (a round has failed to improve the score).
- Read in `/idea-creator` Phase 4 (Critical Review) when challenging a surviving idea's core claim.
- Read whenever a reviewer or investigator is about to write "the root cause is X" — force them to write "the root cause is X, but B and C are plausible alternatives with weights ..." instead.

## Why This Exists

Both adversarial and collaborative review tend to **lock on the first plausible explanation** and then spend the round's budget fixing that explanation. If the first explanation is wrong, the round is wasted. Sparring front-loads a small fixed cost (generating 2 more hypotheses + cheap falsifiers) to avoid that waste.

The protocol is deliberately **compute-cheap**: the cheapest falsifier often uses existing logs, existing metrics, or a <5-minute probe — not a new experiment. The expensive part of a round (training, evaluation) only fires on the surviving hypothesis.

**Adversarial**: "What is wrong with this work?" (one cause)
**Collaborative**: "We are stuck; what are we missing?" (one cause, jointly refined)
**Sparring**: "Before we commit, what are the top three explanations, and which can we kill cheapest?" (multiple causes, falsified before the expensive step)

## The Four-Step Pattern

### Step 1 — Generate ≥3 competing root-cause hypotheses

Each hypothesis must be:
- **Mechanistic** (states WHY failure happens, not WHERE).
- **Different in kind** from the others (not three rewordings of the same cause).
- **Falsifiable** (has observable consequences).

### Step 2 — Assign probability weights

Assign each hypothesis a probability weight in [0, 1] that sums to 1.0. Weights are based on:
- Consistency with existing evidence (logs, prior runs, ablations).
- Plausibility under domain priors.
- Correspondence with known failure modes in `BLACKLIST.md` or `research-wiki`.

**Rule**: no hypothesis receives weight > 0.6 at this stage. If the model tries to weight one at 0.8+, that is the premature-convergence pattern this protocol exists to prevent — force it to spread.

### Step 3 — Specify the cheapest falsifier per hypothesis

For each hypothesis, answer:
- What signal, if observed, would *rule it out*?
- What is the cheapest way to check for that signal? (Order of preference: existing logs > existing model probe > tiny ablation < 30 min > larger experiment.)
- How confident will we be in the falsification? (Binary rule-out vs Bayesian update.)

### Step 4 — Run cheapest discriminator first

Rank the 3+ falsifiers by cost. Run the cheapest one. Update weights. Repeat until either:
- One hypothesis has weight ≥ 0.8, OR
- Falsifier budget exhausted (typically 2 falsifiers).

Only after sparring converges does the expensive round step (training, full evaluation, variant design) fire — on the surviving hypothesis.

## Prompt Stanza

```
[HYPOTHESIS SPARRING]

Current observation / failure pattern: [FAILURE_SUMMARY — raw metrics, not interpretation]

Before committing to a single root cause, produce 3–5 competing mechanistic hypotheses.

For each hypothesis:
1. Hypothesis: [one-sentence mechanistic explanation — WHY this failure happens, not WHERE]
2. Probability weight: [in (0, 0.6); all weights sum to 1.0]
3. Predicted evidence: [what log/metric/probe would look like if this hypothesis were true]
4. Cheapest falsifier:
   - Signal that would rule it out
   - Probe method (prefer: existing logs > existing model probe > <30 min ablation > larger experiment)
   - Estimated cost (minutes of work or compute)
5. Domain-prior support: [one sentence citing prior runs, literature, BLACKLIST, or research-wiki]

Rank the hypotheses by (information gain / falsifier cost). List the ranking.

Then: run the #1-ranked falsifier ONLY. Report the result and update weights. Do NOT design fixes or run experiments before the falsifier completes.
```

## Output Template

For persistence in round logs (e.g., `innovation-logs/round-NN/hypothesis-sparring.md`):

```markdown
## Hypothesis Sparring — Round NN

**Observation**: [failure pattern]

| # | Hypothesis | Weight | Falsifier | Cost | Status |
|---|-----------|--------|-----------|------|--------|
| H1 | ... | 0.45 | ... | ~10 min | FALSIFIED / SURVIVED / UNTESTED |
| H2 | ... | 0.30 | ... | ~20 min | ... |
| H3 | ... | 0.25 | ... | ~5 min | ... |

**Cheapest-first order**: H3 → H1 → H2

**Result after falsifier round**:
- H3: [outcome]
- Updated weights: H1=..., H2=..., H3=...

**Surviving hypothesis**: [which one, with final weight]
**Proceeding with**: [the surviving hypothesis's fix / variant design]
```

## Integration Points

| Skill | Phase | Trigger |
|-------|-------|---------|
| `deep-innovation-loop` | Phase A Step 0.5 (NEW) | Every round — before committing to root cause |
| `auto-review-loop` | Phase A | When `patience_counter ≥ 2` |
| `/idea-creator` | Phase 4 Critical Review | For each surviving idea's core claim |
| `/research-refine` | Phase 2 anchor check | When anchor depends on a load-bearing hypothesis about the field |
| `experiment-bridge` | Phase 5.7 negative-result analysis | When interpreting a failed experiment |

## Relationship to Other Protocols

- **vs. `collaborative-protocol.md`**: collaborative is for when review is circling; sparring is for *not circling in the first place*. Sparring fires at Step 0; collaboration fires after multiple rounds of one-hypothesis thinking.
- **vs. `principle-extraction.md`**: sparring produces hypotheses; extraction produces principles to *test* those hypotheses. They compose: spar → choose surviving hypothesis → extract principles from literature relevant to that hypothesis.
- **vs. adversarial review**: adversarial asks "is this wrong?" about a single claim; sparring asks "among multiple claims, which is most wrong?". Adversarial review operates *after* sparring has chosen a hypothesis to defend.

## Anti-Patterns

| Failure mode | Symptom | Fix |
|--------------|---------|-----|
| Fake diversity | 3 hypotheses are rewordings of one cause | Require each hypothesis to name a *different* failure mechanism category (data, optimization, architecture, metric, pipeline) |
| Weight concentration | One hypothesis weighted ≥ 0.7 in Step 2 | Hard cap weights at 0.6; force reweighting with justification |
| Expensive falsifier picked first | Cheapest-first rule ignored | Require explicit cost estimate; reject falsifiers without it |
| No falsifier (just "run it and see") | "If we train for 200 epochs maybe..." | Reject. A falsifier is a *signal to check*, not "let's try the expensive thing anyway" |
| Skipping sparring because "diagnosis is obvious" | Model claims Step 1 confidence is already > 0.95 | Still run it — if diagnosis is truly obvious, sparring completes in 5 minutes and costs nothing. If it isn't obvious after all, sparring saves the round. |
