# ARIS Agent Guide

> **For AI agents reading this repo.** If you are a human, see [README.md](README.md).

ARIS is a research harness: composable Markdown skills that orchestrate the ML research lifecycle through cross-model adversarial collaboration. This file is a **routing index** — the source of truth for each skill's behavior is its own `skills/<name>/SKILL.md`.

## How to Invoke Skills

**Claude Code / Cursor / Trae:**
```
/skill-name "arguments" — key: value, key2: value2
```

**Codex CLI:**
```
/skill-name "arguments" — key: value
```
Codex skills are in `skills/skills-codex/`.

## Common Parameters

Every skill accepts:
```
— effort: lite | balanced | max | beast      # work intensity (default: balanced)
— human checkpoint: true | false             # pause for approval (default: false)
— AUTO_PROCEED: true | false                 # auto-continue at gates (default: true)
```

Reviewer axes (v2 + v2.1):
```
— reviewer: codex | rescue | adversarial | oracle-pro   # reviewer CHANNEL (backend)
— reviewer-role: adversarial | collaborative | lateral  # reviewer ROLE (prompt template); orthogonal to channel
— assurance: draft | submission              # audit strictness axis (orthogonal to effort); default derived from effort
```

Workflow-specific:
```
— difficulty: medium | hard | nightmare      # reviewer adversarial level
— venue: ICLR | NeurIPS | ICML | ...         # target venue
— sources: web, zotero, deepxiv, ...         # literature sources
— gpu: local | remote | vast | modal         # GPU backend
```

Parameters pass through workflow chains automatically.

## Workflow Index

### Full Pipeline
```
/research-pipeline "direction" → W1 → W1.5 → W2 → W3
```

### Individual Workflows

| Workflow | Invoke | Input | Output | When to use |
|----------|--------|-------|--------|-------------|
| W1: Idea Discovery | `/idea-discovery "direction"` | research direction | IDEA_REPORT.md, EXPERIMENT_PLAN.md | Starting new research |
| W1.5: Experiment Bridge | `/experiment-bridge` | EXPERIMENT_PLAN.md | running code, EXPERIMENT_LOG.md | Have a plan, need to implement |
| W2: Auto Review | `/auto-review-loop "scope"` | paper + results | improved paper | Iterative improvement |
| W2+: Deep Innovation | `/deep-innovation-loop "scope"` | baseline + task | evolved method (40+ rounds) | Methodological innovation |
| W3: Paper Writing | `/paper-writing "NARRATIVE_REPORT.md"` | narrative report | paper/main.pdf | Ready to write |
| W4: Rebuttal | `/rebuttal "paper/ + reviews"` | paper + reviews | PASTE_READY.txt | Reviews received |

### Standalone Skills

| Skill | Invoke | What it does |
|-------|--------|-------------|
| `/alphaxiv "arxiv-id"` | Paper lookup | LLM-optimized summary with tiered fallback |
| `/research-lit "topic"` | Literature survey | Finds papers, builds landscape; v2 auto-extracts principles + failure-patterns |
| `/idea-creator "direction"` | Idea generation | Morphological matrix + SCAMPER + cross-domain leap (v2); failure-library check (v2) |
| `/novelty-check "idea"` | Novelty verification | v2 includes failure-library cross-check (`SEMANTICALLY REDUNDANT` verdict) |
| `/research-review "draft"` | External review | GPT-5.4 xhigh deep critique |
| `/experiment-audit` | Integrity check | Cross-model audit of eval code |
| `/result-to-claim` | Verdict judgment | Codex judges if claims are supported; v2 persists negative verdicts as wiki failure-patterns |
| `/paper-claim-audit "paper/"` | Numerical claim audit | Zero-context cross-reviewer; emits `PAPER_CLAIM_AUDIT.json` per assurance-contract (v2.1) |
| `/citation-audit "paper/"` | Bibliography audit | 3-axis (existence / metadata / context); catches wrong-context citations; emits `CITATION_AUDIT.json` (v2.1) |
| `/proof-checker "paper.tex"` | Proof verification | Math proof audit; emits `PROOF_AUDIT.json` per assurance-contract (v2.1) |
| `/paper-plan "topic"` | Outline creation | Structured outline + claims matrix |
| `/paper-figure "plan"` | Figure generation | Plots from experiment data |
| `/paper-write "plan"` | LaTeX drafting | Section-by-section with citation check |
| `/paper-compile "paper/"` | PDF compilation | Multi-pass with auto-repair |
| `/research-wiki init` | Knowledge base | 6-entity graph (paper/idea/exp/claim/principle/failure-pattern; v2) |
| `/meta-optimize` | Self-improvement | Analyze usage, propose skill edits |
| `/analyze-results` | Result analysis | Statistics and comparison tables |
| `/ablation-planner` | Ablation design | Reviewer-perspective ablations |

## Artifact Contracts

Skills communicate through plain-text files:

| Artifact | Created by | Consumed by |
|----------|-----------|-------------|
| `IDEA_REPORT.md` | idea-discovery | experiment-bridge |
| `EXPERIMENT_PLAN.md` | experiment-plan | experiment-bridge |
| `EXPERIMENT_LOG.md` | experiment-bridge | auto-review-loop, result-to-claim |
| `NARRATIVE_REPORT.md` | auto-review-loop | paper-writing (includes `## Wiki-Sourced Positioning` at v2.1) |
| `paper/main.tex` | paper-write | paper-compile |
| `paper/main.pdf` | paper-compile | auto-paper-improvement-loop |
| `EXPERIMENT_AUDIT.md/.json` | experiment-audit | result-to-claim |
| `PROOF_AUDIT.md/.json` | proof-checker | paper-writing Phase 6 verifier |
| `PAPER_CLAIM_AUDIT.md/.json` | paper-claim-audit | paper-writing Phase 6 verifier |
| `CITATION_AUDIT.md/.json` | citation-audit | paper-writing Phase 6 verifier |
| `paper/.aris/assurance.txt` | paper-writing Phase 0 | verify_paper_audits.sh |
| `paper/.aris/audit-verifier-report.json` | verify_paper_audits.sh | paper-writing Phase 6 (exit-code branch) |
| `research-wiki/` | research-wiki | idea-creator, research-lit, result-to-claim, paper-writing |
| `research-wiki/principles/<slug>.md` (v2) | research-lit Step 2, deep-innovation-loop | idea-creator, auto-review-loop |
| `research-wiki/failures/<slug>.md` (v2) | research-lit Step 2, experiment-bridge, result-to-claim | idea-creator, novelty-check, deep-innovation-loop, auto-review-loop |
| `research-wiki/AUDIT_REPORT.md` (v2) | `/research-wiki audit` | idea-creator Phase 0 |
| `AUTO_REVIEW.md` § `Round N — Feedback Verification` (v2) | auto-review-loop Phase B | Phase C gate; verify_feedback.py |
| `.aris/disputes/round-N-F<id>-round-<R>.json` (v2) | auto-review-loop / auto-paper-improvement-loop dispute step | audit trail |
| `.aris/traces/<skill>/<date>_runNN/` | all reviewer-invoking skills | forensic audit, meta-optimize |
| `.aris/meta/events.jsonl` | hooks (passive) | meta-optimize |

## Cross-Model Protocol

- **Executor** (Claude/Codex): writes code, runs experiments, drafts papers
- **Reviewer** (GPT-5.4/Gemini/GLM): critiques, scores, demands revisions
- **Rule**: executor and reviewer must be different model families
- **Reviewer independence**: pass file paths only, never summaries or interpretations
- **Experiment integrity**: executor must NOT judge its own eval code — reviewer audits directly

### Review Feedback Verification (v2, mandatory)

After receiving any review feedback, the executor **must**:
1. Assign each finding exactly one Step-1 verdict: `Agree | Partially agree | Disagree | Need more info`
2. For `Disagree`, provide file-path:line evidence (gut-feeling rebuttals are auto-rejected)
3. Submit dispute via `/codex:rescue` with structured JSON output (`verdict` ∈ {finding_correct, rebuttal_valid, compromise_needed})
4. Max 3 adjudication rounds per finding; exhaustion → conservative fallback (accept reviewer)
5. Write the per-finding verification table to the skill's log file; Phase C HALTs without it

See `skills/shared-references/codex-context-integrity.md` (Review Feedback Verification Protocol + Execution Enforcement Gates).

### Audit Compliance (v2.1, mandatory at `assurance: submission`)

At `assurance: submission`, every mandatory audit **must** emit a JSON verdict artifact (not silent skip). The six allowed verdicts: `PASS | WARN | FAIL | NOT_APPLICABLE | BLOCKED | ERROR`. `paper-writing` Phase 6 invokes `tools/verify_paper_audits.sh`; non-zero exit blocks Final Report.

See `skills/shared-references/assurance-contract.md` (state machine + artifact schema) + `skills/shared-references/integration-contract.md` (architectural contract).

## Shared References

Read before invoking review-related skills:

**Foundational:**
- `skills/shared-references/reviewer-independence.md` — cross-model review protocol
- `skills/shared-references/experiment-integrity.md` — prohibited fraud patterns
- `skills/shared-references/effort-contract.md` — effort level specifications
- `skills/shared-references/citation-discipline.md` — citation rules
- `skills/shared-references/writing-principles.md` — writing standards
- `skills/shared-references/venue-checklists.md` — venue formatting
- `skills/shared-references/review-tracing.md` — trace artifact protocol
- `skills/shared-references/reviewer-routing.md` — reviewer channel + role routing

**v2 (innovation + failure anti-patterns):**
- `skills/shared-references/principle-extraction.md` — 5-layer principle extraction
- `skills/shared-references/failure-extraction.md` — 5-layer failure anti-pattern extraction
- `skills/shared-references/divergent-techniques.md` — SCAMPER / morphology / inversion / cross-domain / constraint-relaxation
- `skills/shared-references/hypothesis-sparring.md` — ≥3 competing root-cause hypotheses
- `skills/shared-references/reframing-triggers.md` — assumption attack / problem reframing / trajectory reanalysis
- `skills/shared-references/collaborative-protocol.md` — adversarial → collaborative escalation
- `skills/shared-references/post-coding-verification.md` — 3-layer post-coding verification

**v2.1 (audit compliance + architectural contracts):**
- `skills/shared-references/assurance-contract.md` — `assurance: draft|submission` axis + 6-verdict state machine + JSON artifact schema
- `skills/shared-references/integration-contract.md` — 6-component contract for every cross-skill integration
- `skills/shared-references/codex-context-integrity.md` — anti-framing checks + Review Feedback Verification Protocol + HALT-IF-MISSING gates

## Research Wiki

If `research-wiki/` exists in the project, the wiki is a **6-entity graph** (v2):

| Entity | Dir | Node ID |
|--------|-----|---------|
| Paper | `papers/` | `paper:<slug>` |
| Idea | `ideas/` | `idea:<id>` |
| Experiment | `experiments/` | `exp:<id>` |
| Claim | `claims/` | `claim:<id>` |
| **Principle** (v2) | `principles/` | `principle:<slug>` |
| **Failure-pattern** (v2) | `failures/` | `failure-pattern:<slug>` |

Every paper-reading skill (arxiv, alphaxiv, deepxiv, exa-search, semantic-scholar, research-lit) delegates ingest to the canonical helper:
```
python3 tools/research_wiki.py ingest_paper research-wiki/ --arxiv-id <id>
```
Do NOT hand-roll page creation (integration-contract §2).

Principle + failure-pattern extraction (v2) is mandatory in `research-lit` Step 2 for the top 5–8 relevance-ranked papers. Persist via:
```
python3 tools/research_wiki.py upsert_principle ...
python3 tools/research_wiki.py upsert_failure_pattern ...
```

Initialize with `/research-wiki init`. Diagnose with `bash tools/verify_wiki_coverage.sh research-wiki/`.

## Effort Levels

| Level | Tokens | What changes | Default `assurance` |
|-------|:------:|-------------|---------------------|
| `lite` | 0.4x | Fewer papers, ideas, rounds | `draft` |
| `balanced` | 1x | Current default behavior | `draft` |
| `max` | 2.5x | More papers, deeper review | **`submission`** |
| `beast` | 5-8x | Every knob to maximum | **`submission`** |

Codex reasoning is **always xhigh** regardless of effort. `assurance: submission` invokes `verify_paper_audits.sh`; non-zero exit blocks Final Report generation.

## Installation & Uninstallation

```bash
# Global install (serves every Claude Code project)
bash tools/install_aris.sh

# Project-local install
bash tools/install_aris.sh --project /path/to/project

# Preview plan without changes
bash tools/install_aris.sh --dry-run

# Resync with upstream (pulls new skills, removes retired ones)
bash tools/install_aris.sh --reconcile

# Uninstall (wrapper with pre-flight summary)
bash tools/uninstall_aris.sh
bash tools/uninstall_aris.sh --project /path/to/project

# If migrating from legacy cp-r install:
bash tools/uninstall_aris.sh --global --archive-copy   # archives real dirs, then you reinstall via symlinks
```

Windows: use `tools/install_aris.ps1` (junctions, no admin needed). `tools/smart_update.ps1` is a legacy diff tool for cp-r installs; new installs don't need it.

All installations use a manifest at `<install-root>/.aris/installed-skills.txt` for safe uninstall. Safety rules S1–S13 prevent destruction of user-owned files.

## Source of Truth

- Each skill's behavior: read its `skills/<name>/SKILL.md`
- System-wide rules: read `skills/shared-references/*.md`
- Audit contracts: read `skills/shared-references/assurance-contract.md` + `integration-contract.md`
- Review enforcement: read `skills/shared-references/codex-context-integrity.md`
- This guide is a routing index, not the specification.
