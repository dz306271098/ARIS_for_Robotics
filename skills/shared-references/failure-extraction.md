# Failure Anti-Pattern Extraction Protocol

Use this reference when a paper, an experiment, or a prior project produced a **failure** — a reported limitation, a negative ablation result, a diverged training run, an unexpected regression — and you want to convert it into a **reusable, cross-project failure anti-pattern** that can be queried before future methods are designed.

This reference is the symmetric complement to `principle-extraction.md`. Principles describe what makes methods work; failure anti-patterns describe what makes methods fail. Both are stored as first-class wiki entities and queried together during ideation, variant design, and fix-strategy selection.

## When to Read

- Read when `/research-lit` Step 2 extracts principles from top papers — every paper that has a Limitations section or negative ablations also produces ≥ 1 failure anti-pattern.
- Read when `/idea-creator` Phase 4 is about to run the devil's-advocate check on surviving ideas.
- Read when `deep-innovation-loop` Phase E Step 7 processes a regressed variant — the mechanistic cause becomes a new failure anti-pattern.
- Read when `auto-review-loop` Phase C.5.1 (Failure Archaeology) is about to query for prior failures.
- Read when `experiment-bridge` Phase 5.7 processes a negative experimental result.
- Read before persisting any failure record to `research-wiki/failures/` via `/research-wiki upsert_failure-pattern`.

## The Problem This Solves

Failures are the research community's most consistently produced output. Every paper has a Limitations section; every ablation has null results; every project has approaches that didn't work. Yet unlike principles, failures are **almost never extracted, generalized, or cross-referenced**. They stay trapped in the paper's own text, the project's own BLACKLIST, or the author's own memory.

This causes three waste patterns:

1. **Re-invention** — we design a method that embodies principles whose failure modes have been documented 5 times in the last 3 years, with no awareness of any of those documents.
2. **Reactive fix cycles** — we hit a failure, then search literature for "why this fails." The failure was already known; we could have avoided it by querying at design time.
3. **Missed meta-patterns** — failures that span many principles (e.g., "cold-start data scarcity") never get identified as meta-failures, because no single paper's failure is framed that way.

A first-class failure library fixes all three: extraction becomes mandatory at ingest, queries happen at design time (not fix time), and cross-principle clustering surfaces meta-patterns automatically.

## The Five-Layer Extraction

For each reported failure — from a paper's Limitations section, a negative ablation, a prior experiment, or a regressed variant — complete all five layers before persisting.

### Layer 1: Surface Failure (What went wrong?)

Record the specific reported symptom:
- What metric degraded or went out of bounds?
- On which dataset, scale, scenario, or hardware configuration did it fail?
- What was the triggering event (training step, batch size, input type)?

This is factual documentation. It is NOT what you query on.

### Layer 2: Underlying Trigger (Mechanistically, why did it fail?)

Strip implementation details. Answer:
- What property of the method, the data, or the environment caused the failure?
- What invariant was violated?
- What assumption did the method rely on that stopped holding?

**Test**: state the trigger in one sentence without mentioning the paper's architecture, dataset, or specific hyperparameters. If you cannot, you have not yet found the trigger — you are still at Layer 1.

Examples:

| Surface failure | Underlying trigger |
|---|---|
| "Accuracy drops 15% on long-horizon tasks after 20 steps" | "Error accumulation in recurrent state compounds super-linearly when state-update function is not contraction-preserving" |
| "Training diverges at batch size 8K" | "Gradient variance scaling breaks second-order assumption of the optimizer beyond a batch-size threshold" |
| "Zero-shot transfer fails on out-of-distribution tasks" | "Representation space contracts under the training distribution's support and provides no signal outside it" |
| "Sim-to-real gap re-appears after fine-tuning" | "Domain randomization's support does not cover a subspace of the real-world input distribution" |
| "Method works on small benchmarks but not on larger ones" | "Computational complexity grows super-linearly with problem size while performance gain grows sub-linearly" |

### Layer 3: Generalization (Under what conditions does any method fail this way?)

Make the trigger domain-agnostic:
- What structural or statistical conditions reliably produce this failure?
- In what other domains has an equivalent failure been reported?
- What is the most abstract formulation of the failure condition?

**Test**: could a researcher in an unrelated field read your generalized condition and recognize a failure they have seen? If not, the generalization is still too domain-specific.

### Layer 4: Adaptation Check (Does OUR problem satisfy the failure conditions?)

Re-check the generalized condition against your current research context:
- Does our data / architecture / deployment environment match the conditions that trigger this failure?
- If yes: this failure applies. Design must avoid or mitigate it.
- If no: this failure does not apply. Record as "known, does not apply to us, reason: [...]".
- If conditionally: specify the threshold (e.g., "applies if batch size > 4K, which we currently don't use but may scale into").

This is the "query-at-design-time" step — the whole point of making failures first-class.

### Layer 5: Resolution Status (Known resolutions, or open?)

Classify:
- **active** — observed, no known resolution, open research problem
- **resolved** — one or more principles reportedly resolve it (list them)
- **theoretical** — hypothesized but not yet observed in practice (rare; use sparingly)

If resolved, the `resolved_by_principles` list in the wiki entry points to the principles that resolve this failure. This is how the graph closes the loop: for any principle P, we can list its failure modes; for any failure F, we can list the principles that resolve it.

## Output Template

For each extracted failure anti-pattern, produce this record:

```markdown
## Failure Pattern: [kebab-case-name]

- **Source**: [paper citation / project slug / experiment ID]
- **Surface failure**: [1-2 sentences — reported symptom from Layer 1]
- **Underlying trigger**: [1-2 sentences — mechanistic cause from Layer 2, domain-agnostic]
- **Generalized conditions**: [1 sentence — Layer 3: conditions under which this fires for any method]
- **Applies to us?**: yes | no | conditional-on-[specific-threshold]
- **Affects principles**: [principle:<slug>, principle:<slug>, ...]  # which principles embody the pattern that fails
- **Resolved by principles**: [principle:<slug>, ...] or "no known resolution"
- **Status**: active | resolved | theoretical
- **Tags**: [choose subset of: scalability, data-efficiency, optimization, generalization, inference, reproducibility, specification, evaluation]
- **Similar wiki failures**: [failure-pattern:<slug> if ≥ 0.70 Layer-3 similarity]
```

## Integration with research-wiki

When persisting via `/research-wiki upsert_failure-pattern`:
- Dedup rule: Layer-3 generalized form cosine similarity ≥ 0.85 → merge into existing entry (add source paper to `evidence_papers[]`, add manifesting idea/exp to appropriate list).
- Add `failure_mode_of` edges: `failure-pattern → principle` for every principle in `Affects principles`.
- Add `resolved_by` edges: `principle → failure-pattern` for every principle in `Resolved by principles`.
- Add `manifested_as` edges: `idea|experiment → failure-pattern` when the failure was observed in our project.

## Integration Points

| Skill | Phase | What it does with the library |
|-------|-------|------------------------------|
| `/research-lit` | Step 2 (mandatory alongside principle extraction) | Extract failure patterns from top 5-8 papers' Limitations sections; persist to wiki |
| `/idea-creator` | Phase 0 (query_pack read) | "Top unresolved failures" section used as sharp ideation seeds |
| `/idea-creator` | Phase 4 (devil's advocate) | For each idea's principle set, list known failure patterns; flag HIGH-RISK if ≥ 2 principles share failure patterns that have co-manifested in past ideas |
| `deep-innovation-loop` | Phase C (variant design) | Before adversarial challenge, list failure patterns for variant's principles; add to adversarial prompt as "must address" |
| `deep-innovation-loop` | Phase E Step 7 | If variant regressed and Phase 2.7 identified mechanistic cause, upsert as new failure pattern |
| `auto-review-loop` | Phase C.5.1 (Failure Archaeology) | Query wiki FIRST before external literature; if match found with evidence_papers ≥ 3, use `resolved_by_principles` as prior art |
| `experiment-bridge` | Phase 5.7 (negative results) | Extract failure pattern from any experiment producing a statistically significant regression |

## Anti-Patterns

| Failure mode of extraction | Symptom | Fix |
|---------------------------|---------|-----|
| Failure is too specific | "Fails on our dataset" / "Fails with our hyperparameter" | Reformulate Layer 3 at mechanistic level; do not reference paper-specific artifacts |
| Failure is too vague | "Model generalization can be poor" | Specify the structural condition that triggers the failure; vague failures are not queryable |
| Marking active when resolution exists | `status: active` on a failure that principle P resolves | Check if any principle in the wiki has `resolved_by` edge to this failure; upgrade to `resolved` |
| Single-point-of-evidence failure | `evidence_papers: 1`, never queried | Single-evidence failures are recorded but should NOT trigger HIGH-RISK flagging alone; require ≥ 2 to affect design |
| Failure that is really a principle negation | "Learning rate 1e-5 is too low" / "Transformer attention should be multi-head" | These are tuning observations, not failure anti-patterns — keep them in per-project notes |
| No adaptation check | Recording failures without running Layer 4 | Adaptation check is what makes the library actionable — every failure must be classified against our problem before it is useful |

## Difference from BLACKLIST.md

| Aspect | BLACKLIST.md (per-project) | failures/ (wiki, cross-project) |
|--------|---------------------------|--------------------------------|
| Scope | Per-project | Cross-project, cross-time |
| Granularity | Technique-level ("LSTM banned on this task") | Principle-level ("recurrent state without contraction-preserving updates") |
| Source | In-project experiments | Papers, experiments, prior projects |
| Lifetime | Ephemeral (deleted at project end) | Persistent |
| Use | Prevent re-trying failed techniques within one project | Query at design time across all projects |
| Connection | Optional: BLACKLIST entries may link to wiki failure-patterns via `manifested_as` edges | Not required, but recommended for long-lived projects |

Both layers coexist. Per-project BLACKLIST remains authoritative for "don't re-try LSTM here"; wiki failure-patterns provide the principled substrate that informs *why* and enables cross-project transfer of that knowledge.

## Relationship to principle-extraction.md

The two protocols are symmetric:

| principle-extraction.md | failure-extraction.md |
|------------------------|----------------------|
| Layer 1 Surface method | Layer 1 Surface failure |
| Layer 2 Underlying principle | Layer 2 Underlying trigger |
| Layer 3 Generalization | Layer 3 Generalization |
| Layer 4 Adaptation for our problem | Layer 4 Adaptation check (does the failure apply?) |
| Layer 5 Anti-copying guard | Layer 5 Resolution status (known resolutions?) |

A single paper read can extract BOTH: principles from the Method + Results sections, and failure patterns from the Limitations + negative ablations. This is why `research-lit` Step 2 performs both extractions in the same Codex call — zero additional compute.
