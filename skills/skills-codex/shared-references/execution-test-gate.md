# Execution Test Gate

All code-writing workflows in the Codex mainline must pass this gate **before** deployment, experiment launch, or the next external review round.

## Hard requirements

1. **Change map**
   - List the modules, entrypoints, configs, and result paths touched in this round.
   - State what behavior each change is supposed to affect.

2. **Module tests**
   - Every changed module must have at least one runnable test or verification command.
   - If the project has no relevant tests yet, add the smallest credible test first.
   - Static reading is supporting evidence only; it is not a substitute for execution.

3. **Workflow smoke test**
   - Run the smallest real end-to-end path that exercises the changed workflow.
   - Prefer the actual train/eval/inference entrypoint on the smallest viable input.
   - If the full workflow is too expensive, run the minimum faithful slice and document the limitation.

4. **Evidence record**
   - Record commands, inputs, expected outcome, actual outcome, and pass/fail status.
   - A failing gate blocks deploy, re-review, and handoff until fixed or explicitly narrowed.

## Required record template

```markdown
## Mandatory Test Gate

### Change Map
- module / entrypoint:
- intended effect:

### Module Tests
| Target | Command / test | Expected | Actual | Status |
|--------|----------------|----------|--------|--------|
| ... | ... | ... | ... | PASS / FAIL |

### Workflow Smoke Test
- workflow:
- command:
- smallest input / config:
- expected:
- actual:
- status: PASS / FAIL

### Decision
- gate status: PASS / FAIL
- remaining blockers:
```

## Decision rule

- **PASS**: all required module tests and the workflow smoke test pass.
- **FAIL**: any required execution fails, is skipped without a real blocker, or does not exercise the changed behavior.
