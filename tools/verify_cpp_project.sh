#!/usr/bin/env bash
# verify_cpp_project.sh — One-shot integrity verifier for C++ projects.
#
# Runs build → sanitizer → bench; confirms each emits its expected audit JSON
# with verdict acceptable for the declared assurance level. Produces
# CPP_INTEGRITY_REPORT.json summarizing the three gates.
#
# Usage:
#   bash tools/verify_cpp_project.sh <project-root> [--assurance draft|submission]
#                                                    [--json-out PATH]
#
# Exit codes:
#   0  All three gates PASS (or WARN acceptable for draft)
#   1  Any gate FAIL / artifact missing at submission
#   2  Bad usage / contract schema error
set -uo pipefail

ROOT=""
ASSURANCE="draft"
JSON_OUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --assurance) ASSURANCE="$2"; shift 2 ;;
    --json-out) JSON_OUT="$2"; shift 2 ;;
    *) [[ -z "$ROOT" ]] && ROOT="$1" || { echo "unexpected: $1" >&2; exit 2; }; shift ;;
  esac
done
[[ -n "$ROOT" ]] && ROOT="$(cd "$ROOT" && pwd)" || ROOT="$(pwd)"
JSON_OUT="${JSON_OUT:-$ROOT/CPP_INTEGRITY_REPORT.json}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

fail=0
status() {
  # status <artifact> <friendly-name> -> echo a JSON record; set fail=1 on block
  local art="$1" name="$2"
  local path="$ROOT/$art"
  if [[ ! -f "$path" ]]; then
    echo "{\"gate\":\"$name\",\"status\":\"missing\",\"artifact\":\"$art\",\"verdict\":null}"
    [[ "$ASSURANCE" == "submission" ]] && fail=1
    return
  fi
  local verdict
  verdict=$(python3 -c "import json; print(json.load(open('$path')).get('verdict',''))" 2>/dev/null || echo "")
  case "$verdict" in
    PASS|NOT_APPLICABLE)
      echo "{\"gate\":\"$name\",\"status\":\"ok\",\"artifact\":\"$art\",\"verdict\":\"$verdict\"}"
      ;;
    WARN)
      echo "{\"gate\":\"$name\",\"status\":\"warn\",\"artifact\":\"$art\",\"verdict\":\"WARN\"}"
      [[ "$ASSURANCE" == "submission" ]] && fail=1
      ;;
    FAIL|BLOCKED|ERROR)
      echo "{\"gate\":\"$name\",\"status\":\"fail\",\"artifact\":\"$art\",\"verdict\":\"$verdict\"}"
      fail=1
      ;;
    *)
      echo "{\"gate\":\"$name\",\"status\":\"invalid\",\"artifact\":\"$art\",\"verdict\":\"$verdict\"}"
      fail=1
      ;;
  esac
}

REC1=$(status BUILD_ARTIFACT.json build)
REC2=$(status SANITIZER_AUDIT.json sanitize)
REC3=$(status BENCHMARK_RESULT.json bench)

# Contract context (optional)
LANG=$(python3 "$SCRIPT_DIR/project_contract.py" --root "$ROOT" get-language 2>/dev/null || echo unknown)
FRAMEWORKS=$(python3 "$SCRIPT_DIR/project_contract.py" --root "$ROOT" get-frameworks 2>/dev/null || echo "")

cat > "$JSON_OUT" <<EOF
{
  "verifier": "verify_cpp_project.sh",
  "project_root": "$ROOT",
  "assurance": "$ASSURANCE",
  "language": "$LANG",
  "frameworks": "$FRAMEWORKS",
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "gates": [
    $REC1,
    $REC2,
    $REC3
  ],
  "verdict": "$([ $fail -eq 0 ] && echo PASS || echo FAIL)"
}
EOF

if (( fail )); then
  echo "verify_cpp_project: FAIL (see $JSON_OUT)" >&2
  exit 1
fi
echo "verify_cpp_project: PASS (see $JSON_OUT)"
exit 0
