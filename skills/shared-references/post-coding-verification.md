# Post-Coding Verification Protocol

## When to Apply

After EVERY code modification — no exceptions. This protocol runs AFTER `/codex:adversarial-review` passes and BEFORE deployment, experiments, or proceeding to the next phase.

## Three-Layer Verification

### Layer 1: Module Test (isolation)

Verify the modified module works in isolation.

```bash
# 1. Import check — module loads without errors
python3 -c "import sys; sys.path.insert(0, '.'); import <module>"

# 2. Unit test — run existing tests if they exist
python3 -m pytest tests/ -x -q --tb=short 2>/dev/null || echo "No pytest tests found"
python3 -m unittest discover -s tests -q 2>/dev/null || echo "No unittest tests found"

# 3. Minimal I/O verification — run the module with trivial/minimal input
#    Confirm it produces output without crashing
python3 <script> --help 2>/dev/null || python3 <script> --dry-run 2>/dev/null || echo "Manual verification needed"
```

**What to check:**
- No import errors or missing dependencies
- All existing unit tests still pass (zero regressions)
- The script can be invoked with minimal input without crashing
- If the module has a `--dry-run` or `--help` flag, use it
- If the module writes output files, verify the output file is created and non-empty

**If no tests exist:** Create a minimal smoke test inline:
```python
# Smoke test: verify core function runs without error
from <module> import <main_function>
result = <main_function>(minimal_input)
assert result is not None, "Function returned None"
print(f"Smoke test passed: {type(result)}")
```

### Layer 2: Integration Test (workflow)

Verify the modified code integrates correctly with the surrounding workflow.

```bash
# 1. Dependency check — all imports the module needs are available
python3 -c "
import importlib
deps = ['torch', 'numpy', 'wandb', ...]  # read from module imports
for dep in deps:
    try:
        importlib.import_module(dep)
        print(f'OK: {dep}')
    except ImportError:
        print(f'MISSING: {dep}')
"

# 2. Interface compatibility — verify function signatures match callers
#    Check that the modified function's input/output format hasn't changed
#    in a way that breaks other modules that call it

# 3. Config compatibility — verify the module reads config/args correctly
python3 <script> --config <existing_config.yaml> --dry-run 2>/dev/null
```

**What to check:**
- All dependencies are importable in the target environment (local or remote)
- Function signatures and return types haven't changed in breaking ways
- Config files and command-line arguments are still compatible
- If the code reads data files, verify the expected data format hasn't changed
- If the code writes results, verify downstream consumers can still parse the output

### Layer 3: Regression Check (before vs after)

Verify that unmodified functionality still works.

```bash
# 1. Run ALL existing tests (not just the modified module's tests)
python3 -m pytest tests/ -q --tb=short 2>/dev/null

# 2. If no test suite exists, run the pre-existing sanity experiment
#    Compare output against the known-good baseline
python3 <train_script> --max-steps 10 --seed 42 2>&1 | tail -5
# Verify: no NaN, no crash, loss decreasing or stable

# 3. Git diff sanity — verify only intended files changed
git diff --stat HEAD
# Review: are there unexpected file changes?
```

**What to check:**
- Zero test regressions (all previously passing tests still pass)
- Sanity experiment produces reasonable output (no NaN, no crash)
- Only intended files were modified (no accidental changes)

## Decision Gate

| Result | Action |
|--------|--------|
| All 3 layers pass | Proceed to deployment / next phase |
| Layer 1 fails (import/unit test) | Fix immediately — do NOT proceed |
| Layer 2 fails (dependency/interface) | Fix compatibility issue — do NOT proceed |
| Layer 3 fails (regression) | Investigate root cause — revert if needed — do NOT proceed |
| No tests exist AND module is critical | Create minimal smoke test first, then verify |
| No tests exist AND module is non-critical | Layer 1 import + I/O check is sufficient |

## Logging

After verification, log the result:

```markdown
## Post-Coding Verification
- **Module test**: PASS / FAIL (import OK, N tests passed, smoke test OK)
- **Integration test**: PASS / FAIL (M dependencies OK, interface compatible)
- **Regression check**: PASS / FAIL (N tests passed, sanity OK, git diff clean)
- **Decision**: PROCEED / BLOCKED (reason)
```

Append this to `AUTO_REVIEW.md`, `EVOLUTION_LOG.md`, or the skill's cumulative log.

## Scope

This protocol applies at these checkpoints in the workflow:

| Skill | After Phase | Before Phase |
|-------|------------|-------------|
| `experiment-bridge` | Phase 2.3 (code review) | Phase 2.5 (cross-model review) |
| `auto-review-loop` | Step C.1.5 (code review) | Step C.2 (hyperparam sensitivity) |
| `deep-innovation-loop` | Step 1.1 (code review) | Step 1.5 (experiment design) |
| `idea-creator` | Pilot code fix + review | Re-pilot deployment |
| `result-to-claim` | Fix + review | Re-run experiment |

## Key Principles

- **Never skip** — even for "trivial" changes. A one-line fix can break imports.
- **Fast first** — Layer 1 takes seconds. If it fails, don't waste time on Layers 2-3.
- **Automate** — if the project has a test suite, always run it. If not, create smoke tests as you go.
- **Log everything** — verification results are evidence for the reviewer in the next round.
