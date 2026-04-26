#!/usr/bin/env bash
# smoke_shared_refs.sh — Verify every shared-reference file is non-empty + has H1.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

pass() { echo "  ✓ $*"; }
fail() { echo "  ✗ $*" >&2; exit 1; }

echo "[smoke_shared_refs]"

COUNT=0
for f in skills/shared-references/*.md; do
    [[ -s "$f" ]] || fail "$f is empty"
    head -30 "$f" | grep -q '^# ' || fail "$f missing H1 in first 30 lines"
    COUNT=$((COUNT + 1))
done
pass "$COUNT shared-reference files checked (all non-empty, all have H1)"

# Must include the v2, v2.1, and v2.2 additions
REQUIRED=(
    "principle-extraction.md"
    "failure-extraction.md"
    "divergent-techniques.md"
    "hypothesis-sparring.md"
    "reframing-triggers.md"
    "collaborative-protocol.md"
    "codex-context-integrity.md"
    "reviewer-independence.md"
    "reviewer-routing.md"
    "review-tracing.md"
    "effort-contract.md"
    "assurance-contract.md"
    "integration-contract.md"
    "build-system-contract.md"
    "post-coding-verification.md"
    "experiment-integrity.md"
    "citation-discipline.md"
    "writing-principles.md"
    "venue-checklists.md"
    "output-language.md"
    "output-manifest.md"
    "output-versioning.md"
)
for f in "${REQUIRED[@]}"; do
    [[ -f "skills/shared-references/$f" ]] || fail "required shared-ref missing: $f"
done
pass "all ${#REQUIRED[@]} required shared-refs present"

echo "[smoke_shared_refs] ALL PASS"
