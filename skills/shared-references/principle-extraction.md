# Principle Extraction Protocol

Use this reference when `auto-review-loop` (Phase B.5) or `deep-innovation-loop` (Phase B) finds relevant literature and needs to extract reusable insights without copying specific implementations.

This reference defines a structured methodology for transforming specific paper methods into generalizable principles that inspire genuinely novel method designs.

## When to Read

- Read when Phase B / B.5 finds literature relevant to a root cause.
- Read before cataloging any technique from a paper.
- Read when designing method variants in Phase C of deep-innovation-loop.
- Read when experiment-bridge encounters negative results and consults literature (Phase 5.7).

## The Problem This Solves

Research literature contains valuable insights buried inside specific implementations. Directly transplanting those implementations leads to incremental work ("we applied X from paper Y to our domain"). The goal is instead to extract the *principle* that makes a technique effective, generalize it beyond the original domain, and re-specialize it for the current research problem. This produces genuinely novel methods grounded in sound reasoning.

## The Five-Layer Extraction

For each relevant paper or technique found during literature research, complete all five layers before using the technique in method design:

### Layer 1: Surface Method (What did they do?)

Record the specific implementation details:
- Architecture or algorithm name
- Domain and dataset
- Key hyperparameters and design choices
- Reported quantitative results

This is factual documentation. It is NOT what you will use for method design.

### Layer 2: Underlying Principle (Why does it work?)

Strip away all implementation details. Answer:
- What fundamental property or relationship does this method exploit?
- What mathematical, physical, or structural insight makes it effective?
- Would this work if you replaced every component with a different implementation but preserved the core idea?

**Test**: State the principle in one sentence without mentioning any specific architecture, dataset, or paper name. If you cannot, you have not yet found the principle.

Examples of the transformation:

| Surface method | Underlying principle |
|---|---|
| "Attention mechanism over IMU windows" | "Selective weighting of temporal features based on estimated signal reliability" |
| "EKF for gyroscope bias estimation" | "Online estimation of slowly-varying systematic errors through prediction-correction with a physical process model" |
| "Contrastive learning for trajectory embeddings" | "Enforcing that representations preserve metric structure of the output space" |
| "Multi-scale temporal convolution" | "Capturing phenomena that operate at different characteristic timescales by explicit scale decomposition" |
| "Physics-informed loss with gravity constraint" | "Injecting known conservation laws as soft constraints to reduce the feasible solution space" |
| "Graph neural network for skeleton pose" | "Propagating local measurements through a topology that mirrors the physical structure of the system" |

### Layer 3: Generalization (How does this apply beyond the original domain?)

Make the principle domain-agnostic:
- In what other domains has an equivalent principle been applied?
- What is the most abstract formulation of this principle?
- Under what conditions does this principle hold vs. break down?

**Test**: Could a researcher in an unrelated field read your generalized principle and find it useful? If not, the generalization is still too domain-specific.

### Layer 4: Adaptation (How does this principle re-specialize for OUR problem?)

Re-formulate the generalized principle for the current research context:
- Which specific component of our method would benefit from this principle?
- What form would this principle take given our data modalities, constraints, and architecture?
- How does this interact with principles we have already applied?

This is where the principle becomes a concrete design direction. But the design must be ORIGINAL — it should look nothing like the paper's implementation even though it embodies the same principle.

### Layer 5: Anti-Copying Guard

Explicitly separate what to extract from what NOT to copy:

**DO extract** (the principle):
- The insight about why something works
- The mathematical property being exploited
- The structural relationship being captured
- The failure mode being addressed

**DO NOT copy** (the implementation):
- Specific architecture diagrams or module layouts
- Hyperparameter values or training schedules
- Loss function formulations (unless they ARE the principle)
- Code patterns or implementation details
- Evaluation protocols (use your own)

**Verification question**: If the original paper's authors read your method, would they recognize their specific implementation? If yes, you copied too much. If they would recognize the underlying insight but see a genuinely different realization of it, you have succeeded.

## Output Template

For each extracted principle, produce this record:

```markdown
## Principle: [one-sentence principle name]

- **Source paper**: [citation]
- **Surface method**: [1-2 sentences on what the paper specifically did]
- **Underlying principle**: [1-2 sentences on WHY it works, abstracted from implementation]
- **Generalization**: [1 sentence: domain-agnostic formulation]
- **Adaptation for our problem**: [2-3 sentences: how this principle applies to current research]
- **DO NOT copy**: [specific elements from the paper to avoid]
- **Novelty direction**: [how applying this principle differently creates a novel contribution]
- **Status**: EXTRACTED / APPLIED-IN-ROUND-N / SUPERSEDED
```

## Integration with TECHNIQUE_LIBRARY.md (deep-innovation-loop)

When used in deep-innovation-loop, the extracted principles are recorded ALONGSIDE (not replacing) the technique entry in TECHNIQUE_LIBRARY.md. Add `Distilled principle`, `Generalized form`, `Adaptation for our problem`, and `DO NOT copy` fields to each technique entry. During Phase C (Innovation Design), the innovation prompt should reference the distilled principles, not the surface methods.

## Integration with Phase B.5 (auto-review-loop)

When used in auto-review-loop Phase B.5, the extracted principles replace the raw technique descriptions in the fix strategy proposals. Strategy B and Strategy C should be formulated from distilled principles, not from direct transplantation of paper methods.

## Integration with Phase 5.7 (experiment-bridge)

When experiments produce negative results, apply the protocol to 2-3 most relevant papers found during root-cause literature scan. Document extracted principles in the results summary to provide actionable intelligence for the downstream review loop.

## Common Extraction Failures

| Failure mode | Symptom | Fix |
|---|---|---|
| Principle too specific | Mentions paper's domain, dataset, or model name | Remove all domain nouns, re-state using abstract terms |
| Principle too vague | "Use the right features" or "learn better representations" | Add the specific mathematical/structural property being exploited |
| Adaptation is a copy | Implementation resembles the paper's architecture | Re-derive the design from the principle alone, without looking at the paper's solution |
| Missing anti-copying guard | No explicit list of what not to copy | Force yourself to name 3 specific things from the paper you will NOT use |
| Premature fusion | Combining 3+ principles before testing any individually | Apply principles one at a time first, fuse only after individual validation |
