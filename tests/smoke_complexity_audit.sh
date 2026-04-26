#!/usr/bin/env bash
# smoke_complexity_audit.sh — Verify COMPLEXITY_AUDIT.json schema + STALE
# detection integrates with verify_paper_audits.sh.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

pass() { echo "  ✓ $*"; }
fail() { echo "  ✗ $*" >&2; exit 1; }

echo "[smoke_complexity_audit]"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Build a minimal "paper" dir with cpp project contract
mkdir -p "$TMP/.aris" "$TMP/.aris/traces/complexity-claim-audit/run1"
echo "\\documentclass{article}\\begin{document}\\mathcal{O}(n \\log n)\\end{document}" > "$TMP/main.tex"
echo "submission" > "$TMP/.aris/assurance.txt"
HASH=$(sha256sum "$TMP/main.tex" | awk '{print $1}')

# Create COMPLEXITY_AUDIT + three mandatory base audits as PASS
for pair in "COMPLEXITY_AUDIT.json|complexity-claim-audit" \
            "PROOF_AUDIT.json|proof-checker" \
            "PAPER_CLAIM_AUDIT.json|paper-claim-audit" \
            "CITATION_AUDIT.json|citation-audit" \
            "SANITIZER_AUDIT.json|cpp-sanitize" \
            "BENCHMARK_RESULT.json|cpp-bench"; do
  NAME="${pair%|*}"
  SKILL="${pair#*|}"
  cat > "$TMP/$NAME" <<EOF
{
  "audit_skill": "$SKILL",
  "verdict": "NOT_APPLICABLE",
  "reason_code": "no_claims",
  "summary": "smoke",
  "audited_input_hashes": {"main.tex": "sha256:$HASH"},
  "trace_path": ".aris/traces/complexity-claim-audit/run1/",
  "thread_id": "smoke-$$",
  "reviewer_model": "smoke",
  "reviewer_reasoning": "n/a",
  "generated_at": "2026-04-23T00:00:00Z",
  "details": {}
}
EOF
done
touch "$TMP/.aris/traces/complexity-claim-audit/run1/trace.log"

# Project contract declaring cpp — should trigger cpp domain audits
cat > "$TMP/.aris/project.yaml" <<'EOF'
language: cpp
venue_family: theory
build:
  system: cmake
EOF

# Run verifier — all audits present and fresh → exit 0
if bash "$REPO_ROOT/tools/verify_paper_audits.sh" "$TMP" --assurance submission >/dev/null 2>&1; then
  pass "all audits present → verifier exit 0"
else
  bash "$REPO_ROOT/tools/verify_paper_audits.sh" "$TMP" --assurance submission 2>&1 | tail -20
  fail "verifier should accept valid audits (exit 0)"
fi

# Tamper: edit main.tex to invalidate hash → STALE
echo "% edited" >> "$TMP/main.tex"
if bash "$REPO_ROOT/tools/verify_paper_audits.sh" "$TMP" --assurance submission >/dev/null 2>&1; then
  fail "verifier should detect STALE after edit"
fi
pass "STALE detection triggers after source edit"

echo "[smoke_complexity_audit] ALL PASS"
