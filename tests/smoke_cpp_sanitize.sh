#!/usr/bin/env bash
# smoke_cpp_sanitize.sh — Verify that a trivial UB bug is caught by UBSan
# and would produce a FAIL verdict in a SANITIZER_AUDIT.json.
#
# Does not invoke the /cpp-sanitize LLM skill; instead builds a seeded-UB
# test and confirms UBSan flags it. Skips if g++ doesn't support ubsan.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

pass() { echo "  ✓ $*"; }
fail() { echo "  ✗ $*" >&2; exit 1; }
skip() { echo "  ⊘ $*"; }

echo "[smoke_cpp_sanitize]"

if ! command -v g++ >/dev/null 2>&1; then
  skip "g++ missing — skipping"
  echo "[smoke_cpp_sanitize] ALL PASS (skipped)"; exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Seeded UB: signed integer overflow
cat > "$TMP/main.cpp" <<'EOF'
#include <cstdio>
int main() {
    int x = 2147483647;
    int y = x + 1;   // UB: signed overflow
    printf("%d\n", y);
    return 0;
}
EOF

# Build with UBSan
if ! g++ -O0 -fsanitize=undefined -fno-sanitize-recover=all "$TMP/main.cpp" -o "$TMP/app" 2>"$TMP/build.log"; then
  skip "g++ does not support -fsanitize=undefined — skipping"
  echo "[smoke_cpp_sanitize] ALL PASS (skipped)"; exit 0
fi
pass "built with -fsanitize=undefined"

# Run — expect UBSan to flag the overflow (non-zero exit)
if "$TMP/app" > "$TMP/run.out" 2> "$TMP/run.err"; then
  fail "UBSan should have caught signed overflow (app exited 0)"
fi
grep -q "runtime error.*signed integer overflow" "$TMP/run.err" || {
  cat "$TMP/run.err" >&2
  fail "UBSan output did not flag signed integer overflow"
}
pass "UBSan catches seeded signed-integer overflow"

# Synthesize a SANITIZER_AUDIT.json showing FAIL verdict
cat > "$TMP/SANITIZER_AUDIT.json" <<EOF
{
  "audit_skill": "cpp-sanitize",
  "verdict": "FAIL",
  "reason_code": "findings_present",
  "summary": "UBSan found 1 finding.",
  "audited_input_hashes": {"main.cpp": "sha256:$(sha256sum "$TMP/main.cpp" | awk '{print $1}')"},
  "trace_path": "$TMP/trace/",
  "thread_id": "smoke-$$",
  "reviewer_model": "gcc-ubsan",
  "reviewer_reasoning": "n/a",
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "details": {"sanitizers_run": ["undefined"], "findings_count_by_sanitizer": {"undefined": 1}}
}
EOF

python3 -c "
import json
j = json.load(open('$TMP/SANITIZER_AUDIT.json'))
assert j['verdict'] == 'FAIL', j
for k in ['audit_skill','verdict','reason_code','summary','audited_input_hashes','trace_path','thread_id','reviewer_model','reviewer_reasoning','generated_at']:
    assert k in j, f'missing {k}'
print('ok')
" | grep -q ok || fail "synthesized audit JSON missing required fields"
pass "SANITIZER_AUDIT.json schema valid with FAIL verdict"

echo "[smoke_cpp_sanitize] ALL PASS"
