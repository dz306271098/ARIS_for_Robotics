#!/usr/bin/env bash
# smoke_project_contract.sh — Verify project_contract.py CLI end-to-end.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

pass() { echo "  ✓ $*"; }
fail() { echo "  ✗ $*" >&2; exit 1; }

echo "[smoke_project_contract]"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# 1. Detection on empty project → python default
python3 "$REPO_ROOT/tools/project_contract.py" --root "$TMP" get-language | grep -q python || fail "empty dir default not python"
pass "empty directory detected as python"

# 2. Detection on CMake C++ project
touch "$TMP/CMakeLists.txt"
python3 "$REPO_ROOT/tools/project_contract.py" --root "$TMP" get-language | grep -q cpp || fail "CMake project not detected as cpp"
pass "CMakeLists.txt → detected as cpp"

# 3. Detection of cuda via .cu file
touch "$TMP/main.cu"
FWS=$(python3 "$REPO_ROOT/tools/project_contract.py" --root "$TMP" get-frameworks)
echo " $FWS " | grep -q " cuda " || fail ".cu file not detected as cuda framework"
pass ".cu file → cuda framework"

# 4. Init (yaml target) produces a valid contract
python3 "$REPO_ROOT/tools/project_contract.py" --root "$TMP" init --language cpp --frameworks cuda --overwrite --target yaml >/dev/null
[[ -f "$TMP/.aris/project.yaml" ]] || fail "init --target yaml did not create project.yaml"
pass "init --target yaml creates .aris/project.yaml"

# 5. Re-validate
python3 "$REPO_ROOT/tools/project_contract.py" --root "$TMP" validate | grep -q OK || fail "re-validate after init failed"
pass "validate passes after init"

# 6. Build command derived correctly
CMD=$(python3 "$REPO_ROOT/tools/project_contract.py" --root "$TMP" get-build-cmd)
echo "$CMD" | grep -qE "cmake|make" || fail "cpp build-cmd should mention cmake or make: got $CMD"
pass "build-cmd derived: $CMD"

# 7. Metrics derived
METRICS=$(python3 "$REPO_ROOT/tools/project_contract.py" --root "$TMP" get-metrics)
echo "$METRICS" | grep -qw wall_time_ms || fail "metrics missing wall_time_ms: $METRICS"
echo "$METRICS" | grep -qw kernel_time_us || fail "metrics missing kernel_time_us: $METRICS"
pass "metrics include both cpp and cuda primaries"

# 8. Invalid contract → validate non-zero
cat > "$TMP/.aris/project.yaml" <<'EOF'
language: banana
EOF
if python3 "$REPO_ROOT/tools/project_contract.py" --root "$TMP" validate >/dev/null 2>&1; then
  fail "validate should reject language=banana"
fi
pass "validate rejects invalid language"

# 9. CLAUDE.md path takes priority over YAML
TMP2=$(mktemp -d)
trap 'rm -rf "$TMP2"' EXIT
cat > "$TMP2/CLAUDE.md" <<'EOF'
## Project
- language: rust
- venue_family: systems
- frameworks: cuda
- build_system: cargo
- cuda_arch: sm_75
EOF
mkdir -p "$TMP2/.aris"
cat > "$TMP2/.aris/project.yaml" <<'EOF'
language: python
venue_family: ml
EOF
LANG=$(python3 "$REPO_ROOT/tools/project_contract.py" --root "$TMP2" get-language)
[[ "$LANG" == "rust" ]] || fail "CLAUDE.md should override .aris/project.yaml — got language=$LANG"
SOURCE=$(python3 "$REPO_ROOT/tools/project_contract.py" --root "$TMP2" source)
[[ "$SOURCE" == "CLAUDE.md" ]] || fail "expected source=CLAUDE.md, got $SOURCE"
pass "CLAUDE.md takes priority over .aris/project.yaml"

# 10. init --target claude-md scaffolds CLAUDE.md
TMP3=$(mktemp -d)
python3 "$REPO_ROOT/tools/project_contract.py" --root "$TMP3" init --language cpp --frameworks ros2 --target claude-md >/dev/null
[[ -f "$TMP3/CLAUDE.md" ]] || fail "init --target claude-md did not create CLAUDE.md"
grep -q "^## Project" "$TMP3/CLAUDE.md" || fail "scaffolded CLAUDE.md missing ## Project section"
grep -q "^## Container" "$TMP3/CLAUDE.md" || fail "scaffolded CLAUDE.md missing ## Container section"
pass "init --target claude-md scaffolds CLAUDE.md"
rm -rf "$TMP3"

echo "[smoke_project_contract] ALL PASS"
