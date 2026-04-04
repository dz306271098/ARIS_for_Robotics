# Collaborative Problem-Solving Protocol

Use this reference when adversarial review gets stuck — all fix strategies fail, all variants killed, or persistent plateau. Switch from "reviewer vs executor" to "two experts solving together."

## When to Read

- Read when auto-review-loop Phase C.5 exhausts all strategies without validated improvement.
- Read when deep-innovation-loop adversarial challenge kills all variants for 2+ consecutive rounds.
- Read when deep-innovation-loop patience_counter >= 3 (persistent plateau).
- Read when research-review dialogue fails to converge after 5 turns.

## Why This Exists

Adversarial review works well for quality pressure — it catches weaknesses and forces improvement. But adversarial mode has a blind spot: when NEITHER model alone can solve the problem, critiquing each other endlessly doesn't help. The solution is to temporarily switch from competition to collaboration.

**Adversarial**: "What's wrong with this?" → one-way critique
**Collaborative**: "We're both stuck. Here's my evidence. What do you see?" → builds on each other's insights

## The Escalation Pattern

```
Default: ADVERSARIAL (GPT critiques → Claude fixes → GPT re-critiques)
    ↓ stuck?
COLLABORATIVE SESSION (Claude shares evidence + GPT shares theory → joint design)
    ↓ solution found
Return to: ADVERSARIAL (GPT reviews the jointly-designed solution)
```

The adversarial review ALWAYS gets the last word — collaborative mode designs the solution, adversarial mode validates it.

## Multi-Turn Collaborative Session Format

Each session uses `mcp__codex__codex-reply` on the **same threadId** as the adversarial context, so GPT-5.4 has the full history of what was tried and why it failed.

**Turn 1 — Claude shares implementation evidence:**
```
[COLLABORATIVE MODE — Joint Problem Solving]

We've been unable to resolve this through review-fix cycles. Here's the full picture:

- Problem diagnosed as: [root cause from review/diagnosis]
- Approach A tried: [what was implemented, result, why it failed]
- Approach B tried: [what was implemented, result, why it failed]  
- Approach C tried: [what was implemented, result, why it failed]
- What I observe in the code/data/logs: [specific evidence Claude found during implementation]
- Practical constraints discovered: [things that only become apparent during implementation]

I need your help — not as a reviewer, but as a collaborator.

1. Given my implementation evidence, does the root cause diagnosis still hold?
2. What theoretical insight might we both be missing?
3. What approach would account for the practical constraints I discovered?
```

**Turn 2 — GPT provides theoretical analysis + proposal:**
GPT-5.4 responds with revised analysis incorporating Claude's evidence, and proposes a new approach grounded in both theoretical reasoning and implementation reality.

**Turn 3 — Claude provides feasibility feedback:**
Claude evaluates GPT's proposal against the actual codebase, data, and compute constraints. Reports what's feasible, what needs modification, and what can't work.

**Turn 4 — GPT refines based on feasibility:**
GPT adjusts the approach, preserving the core theoretical insight while accommodating practical constraints. States the mathematical/structural property that MUST be preserved.

**Turn 5 — Joint convergence:**
Both agree on the concrete action: what to implement, how, and what result to expect. Claude confirms implementation plan. GPT confirms theoretical soundness.

**Turn 6 (if needed) — Final specification:**
Produce the exact implementation spec — code changes, hyperparameters, evaluation protocol.

## Rules

1. **Max 6 turns per session** — prevent infinite dialogue. If no convergence after 6 turns, document the impasse and proceed with the best available approach.

2. **Each turn must add NEW information** — no repeating what was already said. Valid new information includes:
   - Code/data evidence (Claude)
   - Theoretical insight or mathematical analysis (GPT)
   - Constraint discovery (either)
   - Alternative perspective or reframing (either)

3. **Must produce a CONCRETE action item** — the session must end with a specific implementation plan, not just discussion. Format:
   ```
   COLLABORATIVE SOLUTION:
   - What to implement: [specific code changes]
   - Why it should work: [theoretical justification from GPT + practical validation from Claude]
   - Key constraint preserved: [the mathematical/structural property both agree matters]
   - Expected outcome: [specific metric improvement]
   - Validation plan: [how to verify it actually works]
   ```

4. **After the session, return to adversarial mode** — the jointly-designed solution is implemented by Claude, then reviewed by GPT-5.4 in normal adversarial review. This ensures the collaborative solution meets the same quality bar.

5. **Log the session** — append full collaborative dialogue to the round's documentation with `[COLLABORATIVE SESSION]` tag for traceability.

## When Collaboration Fails

If the 6-turn session doesn't produce a viable solution:
- Document the impasse clearly: what both models agree on, where they disagree
- Record as `[COLLABORATIVE IMPASSE]` in the evolution/review log
- Proceed to next round with the best available approach
- The impasse itself is valuable information — it identifies a genuinely hard problem

## Difference from Existing Patterns

| Aspect | Adversarial (current) | Collaborative (new) |
|--------|----------------------|---------------------|
| Tone | "Score this. What's wrong?" | "We're stuck. Let's solve this together." |
| Direction | One-way (GPT → Claude) | Bi-directional (both contribute) |
| Claude's role | Implement GPT's suggestions | Share evidence, evaluate feasibility, co-design |
| GPT's role | Critique, score, suggest | Analyze evidence, theorize, co-design |
| Output | Weakness list + score | Joint implementation plan |
| When used | Default — every round | Only on escalation — when adversarial is stuck |
