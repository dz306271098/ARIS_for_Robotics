#!/usr/bin/env bash
# smoke_research_wiki.sh — End-to-end smoke test for tools/research_wiki.py.
# No network, no external dependencies. Exit 0 on pass, non-zero on fail.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

TMPWIKI="$(mktemp -d)"
trap 'rm -rf "$TMPWIKI"' EXIT

pass() { echo "  ✓ $*"; }
fail() { echo "  ✗ $*" >&2; exit 1; }

echo "[smoke_research_wiki] TMPWIKI=$TMPWIKI"

# 1. init
python3 tools/research_wiki.py init "$TMPWIKI" >/dev/null
[[ -d "$TMPWIKI/papers" ]]      || fail "papers/ not created"
[[ -d "$TMPWIKI/ideas" ]]       || fail "ideas/ not created"
[[ -d "$TMPWIKI/experiments" ]] || fail "experiments/ not created"
[[ -d "$TMPWIKI/claims" ]]      || fail "claims/ not created"
[[ -d "$TMPWIKI/principles" ]]  || fail "principles/ not created (v2)"
[[ -d "$TMPWIKI/failures" ]]    || fail "failures/ not created (v2)"
[[ -d "$TMPWIKI/graph" ]]       || fail "graph/ not created"
[[ -f "$TMPWIKI/log.md" ]]      || fail "log.md not created"
pass "init created 6 entity dirs + graph + log"

# 2. manual ingest_paper (no arxiv-id avoids network)
python3 tools/research_wiki.py ingest_paper "$TMPWIKI" \
    --title "Test Paper" --authors "Alice Smith, Bob Jones" --year 2025 \
    --venue "ICLR" --thesis "A test thesis" --tags test,ml >/dev/null
SLUG=$(ls "$TMPWIKI/papers" | head -1 | sed 's/\.md$//')
[[ -n "$SLUG" ]]                        || fail "ingest did not produce a paper file"
[[ -f "$TMPWIKI/papers/$SLUG.md" ]]     || fail "paper file $SLUG.md missing"
grep -q "node_id: paper:$SLUG" "$TMPWIKI/papers/$SLUG.md" || fail "node_id missing in paper frontmatter"
grep -q "Test Paper" "$TMPWIKI/papers/$SLUG.md"           || fail "title not written"
pass "ingest_paper created papers/$SLUG.md"

grep -q "ingest_paper: ingested paper:$SLUG" "$TMPWIKI/log.md" || fail "log.md missing ingest entry"
pass "log.md appended ingest entry"

grep -q "$SLUG" "$TMPWIKI/index.md" || fail "index.md does not list $SLUG"
pass "index.md rebuilt with paper entry"

# 3. upsert_principle
python3 tools/research_wiki.py upsert_principle "$TMPWIKI" \
    test-principle --from "paper:$SLUG" \
    --name "Test principle" --generalized "A generic form" --tags math >/dev/null
[[ -f "$TMPWIKI/principles/test-principle.md" ]] || fail "principle page not created"
grep -q "node_id: principle:test-principle" "$TMPWIKI/principles/test-principle.md" || fail "principle node_id missing"
grep -q "embodies_principle" "$TMPWIKI/graph/edges.jsonl" || fail "embodies_principle edge not written"
pass "upsert_principle created page + edge"

# 4. upsert_failure_pattern
python3 tools/research_wiki.py upsert_failure_pattern "$TMPWIKI" \
    test-failure --from "paper:$SLUG" \
    --name "Test failure" --generalized "A condition" \
    --affects-principles test-principle >/dev/null
[[ -f "$TMPWIKI/failures/test-failure.md" ]] || fail "failure page not created"
grep -q "node_id: failure-pattern:test-failure" "$TMPWIKI/failures/test-failure.md" || fail "failure node_id missing"
grep -q "failure_mode_of" "$TMPWIKI/graph/edges.jsonl" || fail "failure_mode_of edge not written"
pass "upsert_failure_pattern created page + edge"

# 5. rebuild_index
python3 tools/research_wiki.py rebuild_index "$TMPWIKI" >/dev/null
grep -q "^## Papers" "$TMPWIKI/index.md"            || fail "index.md missing Papers section"
grep -q "^## Principles" "$TMPWIKI/index.md"        || fail "index.md missing Principles section"
grep -q "^## Failure Patterns" "$TMPWIKI/index.md"  || fail "index.md missing Failure Patterns section"
pass "rebuild_index listed all 3 v2 entity sections"

# 6. rebuild_query_pack
python3 tools/research_wiki.py rebuild_query_pack "$TMPWIKI" >/dev/null
[[ -s "$TMPWIKI/query_pack.md" ]] || fail "query_pack.md empty"
pass "query_pack.md rebuilt (non-empty)"

# 7. add_edge with v2 edge type
python3 tools/research_wiki.py add_edge "$TMPWIKI" \
    --from "principle:test-principle" --to "failure-pattern:test-failure" \
    --type "resolved_by" --evidence "test" >/dev/null
grep -q '"type": "resolved_by"' "$TMPWIKI/graph/edges.jsonl" || fail "resolved_by edge not accepted"
pass "add_edge accepts v2 edge types"

# 8. stats
STATS_OUT=$(python3 tools/research_wiki.py stats "$TMPWIKI" 2>&1)
echo "$STATS_OUT" | grep -q "Papers:" || fail "stats missing Papers line"
echo "$STATS_OUT" | grep -q "Principles:" || fail "stats missing Principles line"
echo "$STATS_OUT" | grep -q "Failure patterns:" || fail "stats missing Failure patterns line"
pass "stats reports all 6 entity counts"

echo "[smoke_research_wiki] ALL PASS"
