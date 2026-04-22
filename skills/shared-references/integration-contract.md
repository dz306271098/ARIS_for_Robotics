# Integration Contract

When one ARIS skill delegates work to another (or to persistent project state), the coupling must be **engineered**, not assumed. This document formalizes what every cross-skill integration inside ARIS must provide.

Rule of thumb: **SKILL.md prose can *describe* an integration; it cannot *guarantee* one.** Any integration whose silent failure would damage the research result needs the six components below. Prose-only "MUST invoke X" has repeatedly failed in practice — the executor skips under context pressure and the caller has no way to detect it.

## Why This Contract Exists — Known Failure Modes

ARIS has hit this class of bug multiple times, always with the same pathology: **one skill "called" another via prose without a canonical helper, a concrete artifact, or a verifier**.

1. **Audit silent-skip (observed in last session's meta-audit).** `/auto-review-loop` Phase B said "verify each weakness" but the verification step was conditional ("if Claude believes..."), had no structured output requirement, and left no artifact a verifier could inspect. Executor defaulted to implicit agreement, multi-turn dispute never fired. Fixed in last session by adding HALT-IF-MISSING gates + per-finding evaluation table + structured dispute JSON — but those fixes were retrofitted per-skill. This contract generalizes the lesson.
2. **Research-wiki ingest no-op.** `/research-wiki init` created `research-wiki/papers/` but no paper ever landed there: `/arxiv`, `/alphaxiv`, `/deepxiv`, `/semantic-scholar`, `/exa-search`, raw `Read`/`WebFetch` — none carried a wiki-ingest hook, and the two that did (`/research-lit`, `/idea-creator`) only had soft prose ("optional and automatic"). The wiki was a tombstone. Fixed by introducing the `ingest_paper` canonical helper (see `tools/research_wiki.py`) + wiring 5 paper-reading skills to delegate.
3. **`effort: beast` skipping audits.** `/paper-writing` ran at `— effort: beast` and could silently skip `/proof-checker`, `/paper-claim-audit`, `/citation-audit` because each phase's content detector (e.g. `if \begin{theorem} exists`) could return negative and the outer prose labeled audits "advisory." Fixed by introducing the orthogonal `assurance` axis (see `assurance-contract.md`) + external verifier (`tools/verify_paper_audits.sh`) whose exit code replaces prose gating.

All three bugs share the same cause: prose MUST without machine-enforceable contract.

## Required Components

Every integration between two ARIS skills (or between a skill and a persistent project artifact) must provide **all six**:

### 1. Activation predicate — single, explicit, observable

A one-line test that says "does this integration fire in this context?" Must be observable from outside the LLM (a file exists, an argument is set, an environment variable is present). Not a vibe, not "probably relevant."

- ✅ `if [ -d research-wiki/ ]`
- ✅ `if assurance == "submission"`
- ✅ `if patience_counter >= 3`
- ❌ "if the user seems to want this"
- ❌ "if the work looks complex enough"

### 2. Canonical helper — one implementation, not copy-pasted

The business logic lives in **exactly one place** — a script under `tools/`, or a single subcommand of an existing helper. Every caller invokes the same entrypoint.

- ✅ `python3 tools/research_wiki.py ingest_paper <root> --arxiv-id <id>`
- ✅ `bash tools/verify_paper_audits.sh <paper> --assurance submission`
- ✅ `/codex:rescue --effort xhigh "..."` (single dispatch helper for Codex dialogue)
- ❌ N skills each paraphrasing the same 10-line bash snippet. When one drifts, they all drift.

If the same 3+ lines of prose appear in more than two SKILL.md files, factor them into a helper.

### 3. Concrete artifact or log entry

Successful execution must leave an observable side effect: a file, a JSON record, a log line. The artifact is the receipt — something a third party (verifier, code reviewer, human auditor) can inspect to answer "did this integration run?"

- ✅ `paper/PROOF_AUDIT.json` with the 6-state verdict schema
- ✅ `research-wiki/papers/<slug>.md` + `research-wiki/log.md` append
- ✅ `AUTO_REVIEW.md` under `## Round N — Feedback Verification` with verdict table
- ✅ `.aris/disputes/round-N-F<id>-round-<R>.json` with structured adjudication
- ❌ "the model said it ran"
- ❌ "you can see it in the conversation"

### 4. Visible checklist — for long workflows

If the integration fires inside a multi-step workflow (paper-writing Phase 6, idea-discovery Phase 7, etc.), render a **visible checkbox block** at the start of the phase so the executor has to confront each row before claiming done. Prose-only "MUST" inside a long SKILL.md is the first thing to get skipped.

```
📋 Submission audits required before Final Report:
   [ ] 1. /proof-checker     → paper/PROOF_AUDIT.json
   [ ] 2. /paper-claim-audit → paper/PAPER_CLAIM_AUDIT.json
   [ ] 3. /citation-audit    → paper/CITATION_AUDIT.json
   [ ] 4. bash tools/verify_paper_audits.sh paper/ --assurance submission
   [ ] 5. Block Final Report iff verifier exit code != 0
```

Cheap, and empirically resists lazy skipping. Skip only for single-step invocations (one-off skills like `/arxiv 2501.12345`).

### 5. Backfill / repair command — explicit manual fallback

An escape hatch for when the integration didn't fire. Users must be able to run a command that **declares** the missed inputs and ingests them retroactively. Prefer explicit arguments over trace-scanning — the helper should not have to guess what to backfill.

- ✅ `python3 tools/research_wiki.py sync --arxiv-ids 2501.12345,1706.03762`
- ✅ `python3 tools/research_wiki.py sync --from-file ids.txt`
- ⚠️ `sync` that scans `.aris/traces/` for arxiv IDs — only as a best-effort secondary mode, not the primary UX, and clearly labeled as heuristic.
- ❌ "Users should remember to..." — humans don't reliably remember.

### 6. Verifier or diagnostic (only when load-bearing)

If silent failure of this integration would damage the research result (wrong numbers shipped to a conference, claims unsupported by evidence, citations in wrong context), a verifier script must exist whose exit code is the source of truth for downstream gates.

- ✅ `tools/verify_paper_audits.sh` — exit 1 blocks Final Report
- ✅ `tools/verify_wiki_coverage.sh` — diagnostic only, reports gaps but does not block (coverage is not load-bearing on any research outcome)

Verifiers must be **external processes** (not LLM self-report), must validate **concrete artifacts** (§3) against a schema, and must emit a structured report callers can parse.

A diagnostic-only verifier (no exit-1 blocking) is still valuable — it surfaces drift to humans. But do not market a diagnostic as a gate.

## Anti-Patterns to Refuse in Review

When reviewing a new integration proposal, reject any of:

- **"Optional and automatic"** — contradicts itself; if it's automatic, it's not optional. Pick one and mean it.
- **"The skill will intelligently decide"** — indecision surface, not a predicate (§1).
- **"Copy the following 10 lines into each caller"** — missing helper (§2); will drift within a month.
- **"The reviewer can see from the logs that..."** — if the evidence is unstructured logs, write a schema and make it an artifact (§3).
- **"Users should remember to..."** — missing backfill (§5); humans don't reliably remember.
- **"Trust the LLM to self-report completion"** — missing verifier (§6) when the failure is load-bearing.
- **"If Claude disagrees, it will..."** — indecision surface; force per-finding evaluation regardless.

## Known ARIS Integrations Under This Contract

| Integration | Predicate | Helper | Artifact | Checklist | Backfill | Verifier |
|---|---|---|---|---|---|---|
| Submission audits (`assurance: submission`) | `paper/.aris/assurance.txt = submission` | `verify_paper_audits.sh` + 3 audit skills emit JSON | `paper/PROOF_AUDIT.json`, `PAPER_CLAIM_AUDIT.json`, `CITATION_AUDIT.json` + `paper/.aris/audit-verifier-report.json` | Phase 6 pre-flight checklist | Rerun the failed audit | `verify_paper_audits.sh` (exit 1 blocks) |
| Research-wiki ingest | `research-wiki/` exists | `research_wiki.py ingest_paper` | `research-wiki/papers/<slug>.md` + `log.md` entry | Step in each paper-reading skill | `research_wiki.py sync --arxiv-ids …` | `verify_wiki_coverage.sh` (diagnostic) |
| Review feedback verification | Any review call with structured output | Per-finding evaluation protocol in `codex-context-integrity.md` | `AUTO_REVIEW.md` / `PAPER_IMPROVEMENT_LOG.md` verification table + `.aris/disputes/*.json` | Phase B of each review loop | Delete state file + rerun affected round | HALT gates in each skill |
| Principle + failure extraction | `research-lit` Step 2 on top 5-8 papers | `upsert_principle` / `upsert_failure-pattern` in `research_wiki.py` | `research-wiki/principles/<slug>.md`, `research-wiki/failures/<slug>.md` | Step 2 of research-lit | `sync` with `--principles-json`/`--failures-json` | `verify_wiki_coverage.sh` (diagnostic) |

When adding a new cross-skill integration, add a row to the table above and confirm all six columns are populated.

## Relationship to Other Contracts

- **`assurance-contract.md`** — implements the submission-audit integration under this contract. Defines the 6-verdict state machine and artifact schema that `verify_paper_audits.sh` rehashes.
- **`codex-context-integrity.md`** — implements the review-feedback-verification integration under this contract. Defines per-finding evaluation, structured dispute JSON, HALT-IF-MISSING gates.
- **`reviewer-independence.md`** — the adjacent constraint for cross-model review (executor never filters reviewer inputs). Independent of this contract but often cited together.
- **`review-tracing.md`** — the artifact protocol for `trace_path` field of audit artifacts. Every mandatory audit's artifact includes `trace_path` pointing to a directory built per this protocol.

## See Also

- `shared-references/assurance-contract.md` — implementation of the paper-writing submission gate under this contract
- `shared-references/codex-context-integrity.md` — implementation of review-feedback verification under this contract
- `shared-references/reviewer-independence.md` — adjacent contract for cross-model review
- `tools/verify_paper_audits.sh`, `tools/research_wiki.py ingest_paper`, `tools/verify_wiki_coverage.sh` — current canonical helpers
