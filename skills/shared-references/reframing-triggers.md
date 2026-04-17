# Reframing Triggers

Use this reference when a loop is correctly diagnosing the same problem round after round but failing to make progress. Re-diagnosis is not reframing — reframing questions whether the *problem* is the right problem, whether the *metric* is the right metric, or whether the *trajectory* that brought us here was the right trajectory to begin with.

This reference defines three trigger-based escalation protocols. Each is strictly **condition-triggered** (not cadence-triggered) so they cost nothing when the loop is making progress and fire only when they are actually needed.

## When to Read

- Read in `deep-innovation-loop` Phase A.5 (NEW) — when collaborative reanalysis converges on a diagnosis.
- Read in `deep-innovation-loop` Phase E Step 2.9 (NEW) — at rounds {15, 30, 45}.
- Read in `deep-innovation-loop` Phase E Step 8 — before every macro phase transition (explore→refine, refine→polish).
- Read in `auto-review-loop` Phase C.6 — during collaborative escalation after Failure Archaeology.
- Read in `research-refine` Phase 2 — once, after anchor is set, to attack its assumptions before the pipeline invests in it.

## Why This Exists

Three loop pathologies are invisible to re-diagnosis:

1. **Comfortable convergence.** Claude and GPT-5.4 agree on a diagnosis. The diagnosis is correct in a narrow sense but rests on hidden assumptions. The loop fixes the stated problem but the assumptions prevent real progress. **Fix**: attack assumptions *after* convergence, when the comfortable zone is at its widest.

2. **Frame trap.** The loop is optimizing the stated objective, on the stated method family, with the stated decomposition. It does this well. But the objective was always the wrong proxy, or the method family was a dead-end commitment from round 0. Re-diagnosis never flags this because re-diagnosis runs *within* the frame. **Fix**: reframe — explicitly propose alternative objectives, decompositions, or method families.

3. **Trajectory lock-in.** The loop committed to principle P at round 3. Every subsequent round builds on P. By round 20, P is load-bearing for dozens of downstream choices. Some of those choices would have been different if P had been different. But nothing in the loop questions P. **Fix**: at macro boundaries (rounds 15, 30, 45), diff the current principle tree against the early commitments and ask what the *earliest* wrong commitment was.

---

## Trigger 1: Assumption Attack

**Fires when**: `deep-innovation-loop` Phase A Step 1 (Collaborative Reanalysis) produces a convergent diagnosis (both Claude and GPT-5.4 agree on the single root cause). Also fires in `auto-review-loop` Phase C.6 and `research-refine` Phase 2 after anchor set.

**What it does**: surfaces hidden assumptions inside a confirmed diagnosis and generates an inverted hypothesis from the most fragile one. The attack runs *once* after convergence — it is a one-pass verification, not a full replacement of the diagnosis.

**Prompt stanza:**

```
[ASSUMPTION ATTACK]

Converged diagnosis: [DIAGNOSIS — the exact root-cause statement that collaborative reanalysis produced]

Step 1 — Parse the diagnosis. Extract every noun and every verb. For each, write the hidden assumption it encodes.
Example: diagnosis = "the policy fails on unseen terrains because the observation space lacks terrain geometry."
Nouns: policy (assumes: a policy is the right computational unit); terrain (assumes: terrain is a meaningful category, not a continuum); observation space (assumes: the problem is observational, not agent-internal).
Verbs: fails (assumes: fail is a binary property, not a spectrum); lacks (assumes: adding geometry is what is needed, not changing representation).

Step 2 — Rank assumptions by fragility (1 = clearly true, 5 = clearly questionable under existing evidence). Require at least one assumption rated ≥ 3.

Step 3 — For the single most fragile assumption, write the inverted hypothesis. Example: inversion of "terrain is a meaningful category" → "terrain is a continuum; categorical terrain labels in the data are mis-binned continuous phenomena."

Step 4 — For the inverted hypothesis, specify:
- What evidence, if it exists, would favor inversion over the converged diagnosis?
- Does any existing evidence (logs, prior runs, ablations) actually look more consistent with inversion than with the diagnosis?
- Cheapest test that distinguishes the two

Step 5 — Decision:
- If evidence is ambiguous OR leans toward inversion → forward inversion to Phase C as a competing variant design
- If evidence clearly supports the original diagnosis → proceed with diagnosis, note the attack-and-survive in the round log
```

**Output**: one markdown block appended to round diagnosis file, labeled `[ASSUMPTION ATTACK — round NN]`, containing:
- Most fragile assumption
- Inverted hypothesis
- Evidence check result
- Decision (proceed / fork into competing variant)

**Budget**: one extra Codex call per attack, ≤ 5 minutes compute.

---

## Trigger 2: Problem Reframing

**Fires when**: macro phase transition in `deep-innovation-loop` Phase E Step 8 (before firing explore→refine or refine→polish), OR plateau persists 3+ rounds with no score improvement despite correct diagnosis.

**What it does**: generates up to 3 reframings of the problem, each tagged by type. The loop can then choose to transition into the reframed problem instead of the next macro phase.

**Three reframing types:**

- **Metric reframing** — the current primary metric is a poor proxy for what we actually care about; propose a different metric, or a weighted combination.
- **Decomposition reframing** — the current split of the problem into sub-problems is arbitrary; propose a different decomposition where sub-problems compose differently.
- **Family reframing** — the current method family is a local-optimum trap; propose a different method family entirely (e.g., abandon policy-learning, try model-based control; abandon reconstruction, try contrastive; abandon end-to-end, try modular).

**Prompt stanza:**

```
[PROBLEM REFRAMING]

Current research anchor: [ANCHOR — problem statement + current method family + primary metric]
Current plateau: [last 3-5 round scores + why the loop plateaued]

Produce up to 3 reframings. For each:
1. Type: metric | decomposition | family
2. Reframed problem statement (one paragraph)
3. What changes — be specific about what stays and what goes
4. Why this reframing is motivated by observed evidence (not speculation)
5. Cost estimate: how much of the existing work carries over vs. needs to be rebuilt
6. Risk: what could go wrong if we reframe and the old frame was actually correct
7. Recommendation: ADOPT / EVALUATE-FIRST / REJECT

Rank reframings by (expected improvement / cost). List the ranking.

If the top-ranked reframing is ADOPT, the next round starts in the reframed problem (not the original).
If the top-ranked is EVALUATE-FIRST, schedule one pilot round that tests the reframing cheaply before committing.
If all are REJECT, the macro transition fires as planned (original problem continues into the next phase).
```

**Output**: `REFRAMING_DECISION.md` in `innovation-logs/round-NN/`, containing all 3 reframings + decision + adopted-or-not rationale.

**Budget**: one Codex call per trigger, ≤ 10 minutes compute. Fires at most 3 times per 50-round run (at 2 macro transitions + 1 plateau trigger).

---

## Trigger 3: Trajectory Reanalysis

**Fires when**: `deep-innovation-loop` rounds {15, 30, 45} — the exact macro boundaries. These are mandatory checkpoints, not condition-triggered.

**What it does**: diffs the current winning lineage (best variant) against round 0 decisions, asks "which early commitment now looks wrong given subsequent evidence?", and proposes a branch-reset experiment if justified.

**The branch-reset concept**: a branch-reset variant takes the current best variant, but *undoes* one early commitment (replacing it with what we now believe it should have been), and tests whether the reset improves results. If expected improvement > 1.5× the current plateau delta, the branch-reset becomes a round N+1 candidate variant.

**Prompt stanza:**

```
[TRAJECTORY REANALYSIS — Checkpoint Round {15|30|45}]

Round 0 commitments: [list of early decisions — method family, representation, supervision, metric, dataset]
Current best variant: [description + score]
Principle tree so far: [TECHNIQUE_LIBRARY.md principles marked TESTED-POSITIVE]
Evolution log: [EVOLUTION_LOG.md — what worked, what failed, what surprised us]

Step 1 — Identify the single earliest commitment that now looks questionable given what we have learned since round 0. State:
- Which commitment (must be from rounds 0–5)
- Why it looked right at the time
- What evidence from rounds 5–current now makes it look questionable
- What the better early commitment would have been

Step 2 — Construct the "branch-reset" variant:
- Take the current best variant
- Replace the questionable commitment with the better one
- Keep everything else (subsequent principles, hyperparameters, design choices) as-is where possible

Step 3 — Estimate expected improvement:
- What plateau delta does the current best variant face?
- What plateau delta would the branch-reset variant face? (Reasoned estimate, not guess — use evidence.)
- Ratio: expected improvement / current plateau delta

Step 4 — Decision:
- If ratio > 1.5 AND cost of branch-reset < 2× a regular round: propose branch-reset as round N+1 candidate variant
- If ratio ≤ 1.5: trajectory is reasonable; no reset this checkpoint
- If cost is prohibitive: log the identified commitment as "retrospectively questionable" for the post-loop reflection

Step 5 — Write the checkpoint decision to TRAJECTORY_REANALYSIS_CHECKPOINT_{15|30|45}.md
```

**Output**: `TRAJECTORY_REANALYSIS_CHECKPOINT_NN.md` containing the analysis, branch-reset proposal (if any), and decision.

**Budget**: one Codex call per checkpoint, ≤ 15 minutes compute. Fires exactly 3 times per 50-round run.

---

## Integration Summary

| Skill | Phase / Step | Trigger | Protocol |
|-------|--------------|---------|----------|
| `deep-innovation-loop` | Phase A.5 (NEW, after Step 1 Collaborative Reanalysis) | Convergent diagnosis | Assumption Attack |
| `deep-innovation-loop` | Phase E Step 8 (macro transition gate, REVISED) | Before every explore→refine / refine→polish | Problem Reframing |
| `deep-innovation-loop` | Phase E Step 2.9 (NEW) | Rounds {15, 30, 45} | Trajectory Reanalysis |
| `auto-review-loop` | Phase C.6 (collaborative escalation, REVISED) | After Failure Archaeology | Assumption Attack + Problem Reframing |
| `research-refine` | Phase 2 (after anchor, REVISED) | Once per research-refine run | Assumption Attack on Research Anchor |

## Relationship to Other Protocols

- **vs. `collaborative-protocol.md`**: collaboration *produces* a convergent diagnosis; Assumption Attack runs *after* to check whether the convergence was premature. Not a replacement — these compose.
- **vs. `hypothesis-sparring.md`**: sparring generates competing hypotheses *before* diagnosis commits; reframing runs *after* diagnosis to question the frame itself. Sparring prevents premature convergence on a cause; reframing prevents premature convergence on a problem.
- **vs. `principle-extraction.md`**: extraction produces principles to *implement*; reframing decides *whether the current implementation direction is right at all*.

## Anti-Patterns

| Failure mode | Symptom | Fix |
|--------------|---------|-----|
| Firing reframing too often | Loop re-frames every round; never accumulates progress | Respect the triggers — don't add cadence-based firing |
| Rejecting every reframing | Protocol fires but always outputs REJECT without evidence | Require explicit counter-evidence for rejection; "I don't want to pivot" is not counter-evidence |
| Adopting a reframing without pilot | Protocol outputs ADOPT on a family reframing with unverified expected-improvement | Require EVALUATE-FIRST for family reframings unless expected improvement is strong and cost is low |
| Skipping Trajectory Reanalysis | Skipped as "expensive" | The 3 checkpoints account for < 5% of a 50-round run's total compute; never skip |
| Inverted-hypothesis stapling | Assumption Attack always adopts the inversion, producing loop thrashing | Require Step 4 evidence check; reject inversions where evidence clearly favors the original |
| Vague "reframing" that is really re-diagnosis | Proposed reframings change the diagnosis but not the problem | Test: does the new statement change the success condition, the decomposition, or the method family? If none of the three, it is re-diagnosis in disguise — reject and re-run |
