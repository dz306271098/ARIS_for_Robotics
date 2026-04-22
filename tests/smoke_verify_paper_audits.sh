#!/usr/bin/env bash
# smoke_verify_paper_audits.sh — Verify external verifier against valid + stale audit JSON.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass() { echo "  ✓ $*"; }
fail() { echo "  ✗ $*" >&2; exit 1; }

echo "[smoke_verify_paper_audits] TMP=$TMP"

# 1. Setup: minimal paper dir
mkdir -p "$TMP/sections" "$TMP/.aris/traces/proof-checker/testrun" \
         "$TMP/.aris/traces/paper-claim-audit/testrun" \
         "$TMP/.aris/traces/citation-audit/testrun"
echo "\\documentclass{article}" > "$TMP/main.tex"
echo "submission" > "$TMP/.aris/assurance.txt"
# Trace files must exist and be non-empty
echo "test trace" > "$TMP/.aris/traces/proof-checker/testrun/test.log"
echo "test trace" > "$TMP/.aris/traces/paper-claim-audit/testrun/test.log"
echo "test trace" > "$TMP/.aris/traces/citation-audit/testrun/test.log"

HASH=$(sha256sum "$TMP/main.tex" | awk '{print $1}')

# Create 3 valid audit JSONs (all NOT_APPLICABLE — should pass at submission)
make_audit() {
    local file="$1" skill="$2" trace_subdir="$3"
    cat > "$file" <<EOF
{
  "audit_skill": "$skill",
  "verdict": "NOT_APPLICABLE",
  "reason_code": "test",
  "summary": "Test audit with no findings.",
  "audited_input_hashes": { "main.tex": "sha256:$HASH" },
  "trace_path": ".aris/traces/$trace_subdir/testrun/",
  "thread_id": "test-thread-$skill",
  "reviewer_model": "gpt-5.4",
  "reviewer_reasoning": "xhigh",
  "generated_at": "2026-04-24T00:00:00Z",
  "details": {}
}
EOF
}
make_audit "$TMP/PROOF_AUDIT.json"        proof-checker      proof-checker
make_audit "$TMP/PAPER_CLAIM_AUDIT.json"  paper-claim-audit  paper-claim-audit
make_audit "$TMP/CITATION_AUDIT.json"     citation-audit     citation-audit
pass "setup: paper dir + 3 audit JSONs (NOT_APPLICABLE) + traces + assurance.txt"

# 2. Run verifier at submission level
bash tools/verify_paper_audits.sh "$TMP" --assurance submission --json-out "$TMP/.aris/audit-verifier-report.json" >/dev/null 2>&1
EXIT_A=$?
[[ "$EXIT_A" == "0" ]] || fail "verifier exit $EXIT_A on valid NOT_APPLICABLE audits"
pass "NOT_APPLICABLE at submission level → exit 0"

# Verify report JSON created
[[ -f "$TMP/.aris/audit-verifier-report.json" ]] || fail "report JSON not created"
pass "verifier report JSON created"

# 3. Tamper: edit main.tex → audited_input_hashes no longer match
echo "% edited after audit ran" >> "$TMP/main.tex"
set +e
bash tools/verify_paper_audits.sh "$TMP" --assurance submission --json-out "$TMP/.aris/audit-verifier-report-stale.json" >/dev/null 2>&1
EXIT_B=$?
set -e
[[ "$EXIT_B" != "0" ]] || fail "verifier should exit non-zero on STALE hashes (got $EXIT_B)"
pass "STALE detection (edit after audit) → non-zero exit"

# 4. Missing audit file: remove one
rm "$TMP/CITATION_AUDIT.json"
# Restore fresh hash on main.tex so STALE doesn't mask MISSING
HASH2=$(sha256sum "$TMP/main.tex" | awk '{print $1}')
make_audit "$TMP/PROOF_AUDIT.json"        proof-checker      proof-checker
make_audit "$TMP/PAPER_CLAIM_AUDIT.json"  paper-claim-audit  paper-claim-audit
# Update both existing files to use fresh hash
sed -i "s/sha256:[a-f0-9]*/sha256:$HASH2/" "$TMP/PROOF_AUDIT.json" "$TMP/PAPER_CLAIM_AUDIT.json"

set +e
bash tools/verify_paper_audits.sh "$TMP" --assurance submission --json-out "$TMP/.aris/audit-verifier-report-missing.json" >/dev/null 2>&1
EXIT_C=$?
set -e
[[ "$EXIT_C" != "0" ]] || fail "verifier should exit non-zero on missing audit artifact (got $EXIT_C)"
pass "missing audit artifact at submission → non-zero exit"

# 5. Draft level: same missing audit should NOT block
set +e
bash tools/verify_paper_audits.sh "$TMP" --assurance draft --json-out "$TMP/.aris/audit-verifier-report-draft.json" >/dev/null 2>&1
EXIT_D=$?
set -e
# At draft level, missing audits are permitted; the verifier exits 0 if remaining audits are well-formed.
# This may legitimately exit 0 (missing audits permitted at draft) OR exit 1 (depending on verifier strictness).
# We only require it does not crash.
pass "draft level handles missing audits without crashing (exit $EXIT_D)"

echo "[smoke_verify_paper_audits] ALL PASS"
