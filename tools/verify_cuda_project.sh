#!/usr/bin/env bash
# verify_cuda_project.sh — One-shot integrity verifier for CUDA projects.
#
# Checks build, sanitizer, profile, correctness artifacts; emits
# CUDA_INTEGRITY_REPORT.json.
#
# Usage:
#   bash tools/verify_cuda_project.sh <project-root> [--assurance draft|submission]
#                                                     [--json-out PATH]
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
JSON_OUT="${JSON_OUT:-$ROOT/CUDA_INTEGRITY_REPORT.json}"

fail=0
status() {
  local art="$1" name="$2" req="${3:-yes}"
  local path="$ROOT/$art"
  if [[ ! -f "$path" ]]; then
    echo "{\"gate\":\"$name\",\"status\":\"missing\",\"artifact\":\"$art\",\"verdict\":null}"
    [[ "$ASSURANCE" == "submission" && "$req" == "yes" ]] && fail=1
    return
  fi
  local verdict
  verdict=$(python3 -c "import json; print(json.load(open('$path')).get('verdict',''))" 2>/dev/null || echo "")
  case "$verdict" in
    PASS|NOT_APPLICABLE) echo "{\"gate\":\"$name\",\"status\":\"ok\",\"artifact\":\"$art\",\"verdict\":\"$verdict\"}" ;;
    WARN) echo "{\"gate\":\"$name\",\"status\":\"warn\",\"artifact\":\"$art\",\"verdict\":\"WARN\"}"; [[ "$ASSURANCE" == "submission" ]] && fail=1 ;;
    FAIL|BLOCKED|ERROR) echo "{\"gate\":\"$name\",\"status\":\"fail\",\"artifact\":\"$art\",\"verdict\":\"$verdict\"}"; fail=1 ;;
    *) echo "{\"gate\":\"$name\",\"status\":\"invalid\",\"artifact\":\"$art\",\"verdict\":\"$verdict\"}"; fail=1 ;;
  esac
}

REC1=$(status CUDA_BUILD_ARTIFACT.json build)
REC2=$(status CUDA_SANITIZER_AUDIT.json sanitize)
REC3=$(status CUDA_PROFILE_REPORT.json profile)
REC4=$(status CUDA_CORRECTNESS_AUDIT.json correctness)
REC5=$(status TRT_ENGINE_AUDIT.json tensorrt no)  # optional — only required if framework: tensorrt

cat > "$JSON_OUT" <<EOF
{
  "verifier": "verify_cuda_project.sh",
  "project_root": "$ROOT",
  "assurance": "$ASSURANCE",
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "gates": [
    $REC1,
    $REC2,
    $REC3,
    $REC4,
    $REC5
  ],
  "verdict": "$([ $fail -eq 0 ] && echo PASS || echo FAIL)"
}
EOF

if (( fail )); then echo "verify_cuda_project: FAIL (see $JSON_OUT)" >&2; exit 1; fi
echo "verify_cuda_project: PASS (see $JSON_OUT)"
exit 0
