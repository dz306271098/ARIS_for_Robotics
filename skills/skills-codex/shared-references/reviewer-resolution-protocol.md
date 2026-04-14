# Reviewer Resolution Protocol

Use this protocol whenever reviewer feedback is contested, overstated, or ambiguous.

## Classification

Every reviewer finding must end in one of four states:

- `accepted` — reviewer is correct as stated
- `narrowed` — reviewer found a real issue, but the scope or wording was too broad
- `rebutted` — reviewer claim does not hold after checking the actual evidence
- `unresolved` — more experiment, analysis, or claim change is still required

No finding is allowed to remain as an unclassified vague objection.

## Required flow

1. **Check locally first**
   - Read raw files, diffs, metrics, and logs directly.
   - Gather the exact evidence for or against the reviewer finding.

2. **Reply in the same reviewer thread**
   - For `narrowed`, `rebutted`, or `unresolved` findings, go back to the same reviewer thread.
   - Ask the reviewer to re-check only the disputed items against the concrete evidence.

3. **Bound the discussion**
   - After 3 rounds on the same issue, write a `Convergence Memo`.
   - After 5 rounds, stop open-ended debate and ask for a resolution-only action plan.

4. **Force a real resolution**
   - Each unresolved item must end with one minimal next action:
     - add experiment
     - add analysis
     - change implementation
     - narrow or withdraw the claim

## Convergence Memo template

```markdown
## Convergence Memo
- settled:
- contested:
- unknown:
- minimum resolution path:
```

## Resolution-only follow-up prompt

```text
We need to converge on these disputed items only.

For each item, return the minimum action that resolves it:
- experiment
- analysis
- implementation fix
- claim change

Do not restate the whole review.
```
