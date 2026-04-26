#!/usr/bin/env bash
# verify_ros2_project.sh — One-shot integrity verifier for ROS2 projects.
#
# Checks build, launch-test, and realtime-audit artifacts. Emits
# ROS2_INTEGRITY_REPORT.json.
#
# Usage:
#   bash tools/verify_ros2_project.sh <project-root> [--assurance draft|submission]
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
JSON_OUT="${JSON_OUT:-$ROOT/ROS2_INTEGRITY_REPORT.json}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

fail=0
status() {
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
    PASS|NOT_APPLICABLE) echo "{\"gate\":\"$name\",\"status\":\"ok\",\"artifact\":\"$art\",\"verdict\":\"$verdict\"}" ;;
    WARN) echo "{\"gate\":\"$name\",\"status\":\"warn\",\"artifact\":\"$art\",\"verdict\":\"WARN\"}"; [[ "$ASSURANCE" == "submission" ]] && fail=1 ;;
    FAIL|BLOCKED|ERROR) echo "{\"gate\":\"$name\",\"status\":\"fail\",\"artifact\":\"$art\",\"verdict\":\"$verdict\"}"; fail=1 ;;
    *) echo "{\"gate\":\"$name\",\"status\":\"invalid\",\"artifact\":\"$art\",\"verdict\":\"$verdict\"}"; fail=1 ;;
  esac
}

REC1=$(status ROS2_BUILD_ARTIFACT.json build)
REC2=$(status ROS2_LAUNCH_TEST_AUDIT.json launch_test)
REC3=$(status ROS2_REALTIME_AUDIT.json realtime_audit)

DISTRO=$(python3 -c "
import sys, json
try:
    import yaml
    cfg = yaml.safe_load(open('$ROOT/.aris/project.yaml')) or {}
except Exception:
    cfg = {}
print((cfg.get('build') or {}).get('ros2_distro',''))
" 2>/dev/null || echo "")

cat > "$JSON_OUT" <<EOF
{
  "verifier": "verify_ros2_project.sh",
  "project_root": "$ROOT",
  "assurance": "$ASSURANCE",
  "ros2_distro": "$DISTRO",
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "gates": [
    $REC1,
    $REC2,
    $REC3
  ],
  "verdict": "$([ $fail -eq 0 ] && echo PASS || echo FAIL)"
}
EOF

if (( fail )); then echo "verify_ros2_project: FAIL (see $JSON_OUT)" >&2; exit 1; fi
echo "verify_ros2_project: PASS (see $JSON_OUT)"
exit 0
