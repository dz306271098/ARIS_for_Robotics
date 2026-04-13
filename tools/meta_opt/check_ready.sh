#!/usr/bin/env bash
# ARIS Meta-Optimize: Readiness Check
# Called by SessionEnd hook. If enough data has accumulated,
# outputs a reminder to stdout (injected into Claude's context).
#
# Trigger: ≥5 skill invocations since last /meta-optimize run

set -euo pipefail

ARIS_META_DIR="${CLAUDE_PROJECT_DIR:-.}/.aris/meta"
EVENTS_FILE="$ARIS_META_DIR/events.jsonl"
LAST_RUN_FILE="$ARIS_META_DIR/.last_optimize"

# No log = nothing to check
[ -f "$EVENTS_FILE" ] || exit 0

# Count skill invocations
TOTAL_SKILLS=$(grep -c '"skill_invoke"' "$EVENTS_FILE" 2>/dev/null || echo 0)

# Check when meta-optimize was last run
if [ -f "$LAST_RUN_FILE" ]; then
    LAST_TS=$(cat "$LAST_RUN_FILE")
    # Count skill invocations AFTER last run by parsing the JSONL timestamp field.
    SINCE_LAST=$(python3 - "$EVENTS_FILE" "$LAST_TS" <<'PY'
import json
import sys

events_path = sys.argv[1]
last_ts = sys.argv[2]
count = 0

with open(events_path, encoding="utf-8") as f:
    for raw in f:
        raw = raw.strip()
        if not raw:
            continue
        try:
            payload = json.loads(raw)
        except json.JSONDecodeError:
            continue
        if payload.get("event") == "skill_invoke" and payload.get("ts", "") > last_ts:
            count += 1

print(count)
PY
)
else
    SINCE_LAST=$TOTAL_SKILLS
fi

# Threshold: 5 skill invocations since last optimize
if [ "$SINCE_LAST" -ge 5 ]; then
    echo "📊 ARIS has logged $SINCE_LAST skill runs since last optimization. Run /meta-optimize to check for improvement opportunities."
fi
