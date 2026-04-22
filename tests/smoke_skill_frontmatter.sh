#!/usr/bin/env bash
# smoke_skill_frontmatter.sh — Every skills/*/SKILL.md must have YAML name + description.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

pass() { echo "  ✓ $*"; }
fail() { echo "  ✗ $*" >&2; exit 1; }

echo "[smoke_skill_frontmatter]"

COUNT=0
CITATION_AUDIT_SEEN=false
for skill in skills/*/SKILL.md; do
    # Skip shared-references (it's not a skill)
    [[ "$skill" == *"shared-references"* ]] && continue
    # Skip skills-codex bundles (they're not individual skills)
    dir=$(dirname "$skill")
    name=$(basename "$dir")
    case "$name" in
        skills-codex*) continue ;;
    esac

    # Read first 30 lines
    head -30 "$skill" | grep -q '^name:' || fail "$skill missing 'name:' frontmatter"
    head -30 "$skill" | grep -q '^description:' || fail "$skill missing 'description:' frontmatter"
    COUNT=$((COUNT + 1))

    [[ "$name" == "citation-audit" ]] && CITATION_AUDIT_SEEN=true
done
pass "$COUNT top-level skills have valid frontmatter"

$CITATION_AUDIT_SEEN || fail "citation-audit skill (v2.1) not found"
pass "citation-audit skill present"

# Also check root-level SKILL.md count matches README
# (52 after citation-audit added; we count individual skills excluding bundles)
(( COUNT >= 50 )) || fail "expected ≥50 skills, got $COUNT"
pass "skill count sanity: $COUNT skills"

echo "[smoke_skill_frontmatter] ALL PASS"
