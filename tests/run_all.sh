#!/usr/bin/env bash
# run_all.sh — ARIS smoke test umbrella.
# Runs v2.1 + v2.2 host smoke tests; optionally dispatches container tests.
#
# Flags:
#   --with-container    Run host tests AND tests/container/run_all.sh via tools/container_run.sh
#   --container-only    Skip host tests, run only container tests
#   --host-only         Default — run only host tests (backward-compat)

set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MODE="host-only"
for arg in "$@"; do
    case "$arg" in
        --with-container) MODE="with-container" ;;
        --container-only) MODE="container-only" ;;
        --host-only) MODE="host-only" ;;
        *) echo "unknown arg: $arg" >&2; exit 2 ;;
    esac
done

TESTS=(
    "smoke_shared_refs.sh"
    "smoke_skill_frontmatter.sh"
    "smoke_research_wiki.sh"
    "smoke_install_aris.sh"
    "smoke_uninstall_aris.sh"
    "smoke_verify_paper_audits.sh"
    "smoke_verify_wiki_coverage.sh"
    "smoke_project_contract.sh"
    "smoke_container_run.sh"
    "smoke_claude_md_contract.sh"
    "smoke_paper_writing_dispatch.sh"
    "smoke_cpp_build.sh"
    "smoke_cpp_sanitize.sh"
    "smoke_complexity_audit.sh"
    "smoke_failure_seeds.sh"
)

PASS=0
FAIL=0
FAILED_NAMES=()

echo "════════════════════════════════════════════════════"
echo "  ARIS v2.2 Smoke Test Suite ($MODE)"
echo "════════════════════════════════════════════════════"

if [[ "$MODE" != "container-only" ]]; then
    for t in "${TESTS[@]}"; do
        echo ""
        echo "▶ Running $t"
        if bash "$SCRIPT_DIR/$t"; then
            PASS=$((PASS + 1))
        else
            FAIL=$((FAIL + 1))
            FAILED_NAMES+=("$t")
        fi
    done
fi

if [[ "$MODE" == "with-container" || "$MODE" == "container-only" ]]; then
    echo ""
    echo "▶ Running container-side suite (tests/container/run_all.sh)"
    if [[ ! -f "$SCRIPT_DIR/container/run_all.sh" ]]; then
        echo "  ✗ tests/container/run_all.sh not found"
        FAIL=$((FAIL + 1))
        FAILED_NAMES+=("container-suite (missing)")
    elif [[ ! -f "$REPO_ROOT/.aris/container.yaml" ]]; then
        echo "  ⊘ .aris/container.yaml not configured — skipping container suite"
    elif bash "$REPO_ROOT/tools/container_run.sh" --root "$REPO_ROOT" -- bash -c "test -d /tmp/aris-container-tests" >/dev/null 2>&1 || true; then
        # Dispatch container test runner through container_run
        if bash "$SCRIPT_DIR/container/run_all.sh"; then
            PASS=$((PASS + 1))
        else
            FAIL=$((FAIL + 1))
            FAILED_NAMES+=("container-suite")
        fi
    fi
fi

echo ""
echo "════════════════════════════════════════════════════"
echo "  Summary: $PASS passed, $FAIL failed"
if (( FAIL > 0 )); then
    echo "  FAILED:"
    for n in "${FAILED_NAMES[@]}"; do echo "    - $n"; done
fi
echo "════════════════════════════════════════════════════"

(( FAIL == 0 ))
