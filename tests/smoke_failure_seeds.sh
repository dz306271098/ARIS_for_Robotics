#!/usr/bin/env bash
# smoke_failure_seeds.sh — Verify that seed_cpp_ros2_cuda_failure_patterns.sh
# creates all 15 canonical failure patterns in a fresh wiki.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

pass() { echo "  ✓ $*"; }
fail() { echo "  ✗ $*" >&2; exit 1; }

echo "[smoke_failure_seeds]"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

bash "$REPO_ROOT/tools/seed_cpp_ros2_cuda_failure_patterns.sh" "$TMP/wiki" >/dev/null 2>&1 || fail "seed script exited non-zero"

COUNT=$(ls "$TMP/wiki/failures/" | wc -l)
(( COUNT == 15 )) || fail "expected 15 failure patterns, got $COUNT"
pass "15 failure patterns seeded"

# Verify domain representation
CPP=$(ls "$TMP/wiki/failures/" | grep -cE "^(ub-exploit|hidden-asymptotic|cache-thrash|numerical|race-condition|memory-fragment)") || true
ROS2=$(ls "$TMP/wiki/failures/" | grep -c "^ros2-") || true
CUDA=$(ls "$TMP/wiki/failures/" | grep -c "^cuda-") || true

(( CPP == 6 )) || fail "expected 6 C++ patterns, got $CPP"
(( ROS2 == 4 )) || fail "expected 4 ROS2 patterns, got $ROS2"
(( CUDA == 5 )) || fail "expected 5 CUDA patterns, got $CUDA"
pass "6 C++ + 4 ROS2 + 5 CUDA patterns as designed"

# Verify YAML frontmatter present
for f in "$TMP/wiki/failures"/*.md; do
  head -5 "$f" | grep -q "^node_id: failure-pattern:" || fail "$f missing node_id frontmatter"
done
pass "all seeds have valid node_id frontmatter"

echo "[smoke_failure_seeds] ALL PASS"
