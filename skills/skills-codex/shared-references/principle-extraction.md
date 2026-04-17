# Principle Extraction Protocol

Use this protocol whenever a workflow reads papers for innovation, planning, failure recovery, or literature synthesis.

The goal is to extract **transferable principles**, not to cargo-cult paper-specific modules.

## Why This Exists

A paper can be useful in three different ways:

1. as direct prior work to compare against
2. as a warning about what already failed or saturated
3. as a source of a **general principle** that can be adapted in a new domain

Most weak literature use stops at level 1. This protocol forces the workflow to reach level 3.

## Five Layers

For every relevant paper or method, write down five layers:

### Layer 1: Surface Method

- What did the paper literally build?
- Which modules, losses, data sources, or training stages were used?
- What benchmark or domain was it designed for?

This layer is only the entry point. Do not stop here.

### Layer 2: Distilled Principle

Write one sentence that explains **why** the method works.

Rules:
- no paper title words
- no benchmark names
- no module names unless absolutely unavoidable
- must still make sense in a different domain

Good example:
- "Introduce a state that makes the hidden variable observable before asking the policy to predict long-horizon actions."

Bad example:
- "Use Module-X with Loss-Y on Dataset-Z."

### Layer 3: Preconditions

State when the principle should work.

- What hidden assumption does it rely on?
- What data, structure, or signal must exist?
- What breaks if those preconditions are false?

This is the anti-hallucination layer.

### Layer 4: Adaptation To Our Problem

Translate the principle into the current project:

- Which bottleneck or failure mode does it address?
- Where would it attach in our pipeline?
- What is the smallest adaptation that preserves the principle?
- Which parts of the original paper are irrelevant and should be dropped?

### Layer 5: Must Not Copy

Explicitly record what should **not** be transplanted:

- domain-specific scaffolding
- paper-specific benchmark tricks
- extra modules that are not essential to the principle
- evaluation artifacts masquerading as method gains

## One-Sentence Test

A principle passes only if this sentence is meaningful:

"Even if the original paper disappeared, this idea would still be useful because ..."

If that sentence cannot be completed cleanly, the extraction is still too shallow.

## Output Template

```markdown
## [Principle Name]

- Source paper:
- Surface method:
- Distilled principle:
- Preconditions:
- Adaptation to our project:
- Must not copy:
- Related bottlenecks:
- Related ideas / experiments:
```

## Integration Rules

- `research-lit` uses this protocol while building `PRINCIPLE_BANK.md`.
- `idea-creator` uses the distilled principles and preconditions, not raw paper titles, as ideation inputs.
- `research-refine` and `experiment-plan` use the adaptation layer to generate route portfolios.
- `deep-innovation-loop` uses this protocol for new techniques discovered during Phase B and must write successful principles back into the shared memory layer.
- `experiment-bridge` and `result-to-claim` use it for failure recovery so negative runs still create reusable knowledge.
