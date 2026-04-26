#!/usr/bin/env bash
# smoke_paper_writing_dispatch.sh — Verify that paper-writing/SKILL.md Phase 6
# documents the auto-fan-out logic correctly: every domain audit JSON listed
# in the verifier's MANDATORY_AUDITS table appears in the Phase 6 fan-out
# block, so the user's one-click `/paper-writing — assurance: submission`
# actually produces all artifacts the verifier will demand.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

pass() { echo "  ✓ $*"; }
fail() { echo "  ✗ $*" >&2; exit 1; }

echo "[smoke_paper_writing_dispatch]"

PW="$REPO_ROOT/skills/paper-writing/SKILL.md"
VERIFIER="$REPO_ROOT/tools/verify_paper_audits.sh"

[[ -f "$PW" ]] || fail "paper-writing SKILL.md missing"
[[ -f "$VERIFIER" ]] || fail "verify_paper_audits.sh missing"

# 1. Phase 6 must contain the auto-fan-out section
grep -q "Auto-fan-out" "$PW" || fail "Phase 6 missing 'Auto-fan-out' fan-out documentation"
pass "Phase 6 contains 'Auto-fan-out' section"

# 2. Each domain audit skill mentioned in verify_paper_audits.sh DOMAIN_AUDITS
# must appear as a /skill invocation in Phase 6
DOMAIN_SKILLS=(
  "/cpp-build" "/cpp-sanitize" "/cpp-bench"
  "/cuda-build" "/cuda-sanitize" "/cuda-profile" "/cuda-correctness-audit"
  "/ros2-build" "/ros2-launch-test" "/ros2-realtime-audit"
  "/tensorrt-engine-audit"
  "/complexity-claim-audit"
)

MISSING=()
for s in "${DOMAIN_SKILLS[@]}"; do
  if ! grep -q "$s" "$PW"; then
    MISSING+=("$s")
  fi
done

if (( ${#MISSING[@]} > 0 )); then
  fail "missing fan-out invocations in paper-writing Phase 6: ${MISSING[*]}"
fi
pass "all 12 domain skills referenced in Phase 6 fan-out"

# 3. Phase 6 must reference project_contract.py to read frameworks
grep -q "project_contract.py get-language\|project_contract.py get-frameworks" "$PW" \
  || fail "Phase 6 should consult project_contract.py to choose dispatch path"
pass "Phase 6 reads from project_contract.py"

# 4. Verifier domain table includes the same skills
for s in cpp-sanitize cpp-bench cuda-sanitize cuda-profile cuda-correctness-audit \
         ros2-launch-test ros2-realtime-audit tensorrt-engine-audit complexity-claim-audit; do
  if ! grep -q "$s" "$VERIFIER"; then
    fail "verifier's DOMAIN_AUDITS missing $s — fan-out and verifier out of sync"
  fi
done
pass "verifier DOMAIN_AUDITS table aligned with fan-out skills"

# 5. Auto-fan-out conditional on assurance: submission
grep -q "assurance.*submission" "$PW" || fail "fan-out should be gated on assurance: submission"
pass "fan-out gated on assurance: submission"

echo "[smoke_paper_writing_dispatch] ALL PASS"
