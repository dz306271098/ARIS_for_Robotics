#!/usr/bin/env bash
# smoke_claude_md_contract.sh — Verify CLAUDE.md ## Project / ## Container
# parser end-to-end + priority over .aris/project.yaml.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

pass() { echo "  ✓ $*"; }
fail() { echo "  ✗ $*" >&2; exit 1; }

echo "[smoke_claude_md_contract]"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Author a representative CLAUDE.md
cat > "$TMP/CLAUDE.md" <<'EOF'
# Some Project

## Some Existing Section
- gpu: local

## Project
- language: cpp
- venue_family: robotics
- frameworks: ros2, cuda
- build_system: colcon
- cuda_arch: sm_86
- ros2_distro: jazzy
- bench_harness: rosbag-replay
- bench_iterations: 5
- sanitizers_cpu: address, undefined, thread
- sanitizers_gpu: memcheck, racecheck
- profile_cpu_tool: perf
- profile_gpu_tool: nsight-compute

## Container
- runtime: docker
- name: my-test-container
- workdir: /tmp/aris-claude-md-test
- pre_exec: export FOO=bar
- pre_exec: export BAZ=qux
EOF

# 1. Source resolution
SRC=$(python3 "$REPO_ROOT/tools/project_contract.py" --root "$TMP" source)
[[ "$SRC" == "CLAUDE.md" ]] || fail "expected source=CLAUDE.md, got '$SRC'"
pass "contract source resolved to CLAUDE.md"

# 2. Project fields
LANG=$(python3 "$REPO_ROOT/tools/project_contract.py" --root "$TMP" get-language)
[[ "$LANG" == "cpp" ]] || fail "language: expected cpp, got $LANG"
pass "language=$LANG"

FWS=$(python3 "$REPO_ROOT/tools/project_contract.py" --root "$TMP" get-frameworks)
echo " $FWS " | grep -q " ros2 " || fail "frameworks missing ros2: $FWS"
echo " $FWS " | grep -q " cuda " || fail "frameworks missing cuda: $FWS"
pass "frameworks=$FWS"

BUILD=$(python3 "$REPO_ROOT/tools/project_contract.py" --root "$TMP" get-build-cmd)
echo "$BUILD" | grep -qi "colcon" || fail "build-cmd should be colcon: $BUILD"
pass "build-cmd=$BUILD"

# 3. Sanitizer + profile fields parsed
SHOW=$(python3 "$REPO_ROOT/tools/project_contract.py" --root "$TMP" show)
echo "$SHOW" | python3 -c "
import json, sys
cfg = json.load(sys.stdin)
assert cfg.get('build', {}).get('cuda_arch') == 'sm_86', cfg
assert cfg.get('build', {}).get('ros2_distro') == 'jazzy', cfg
assert cfg.get('bench', {}).get('iterations') == 5, cfg
assert 'address' in cfg.get('sanitizers', {}).get('cpu', []), cfg
assert 'memcheck' in cfg.get('sanitizers', {}).get('gpu', []), cfg
assert cfg.get('profile', {}).get('gpu_tool') == 'nsight-compute', cfg
print('ok')
" | grep -q ok || fail "structured fields not correctly parsed"
pass "build / bench / sanitizers / profile fields all parsed"

# 4. Container section parsed correctly
CTR=$(python3 "$REPO_ROOT/tools/project_contract.py" --root "$TMP" get-container)
echo "$CTR" | python3 -c "
import json, sys
ctr = json.load(sys.stdin)
assert ctr.get('runtime') == 'docker', ctr
assert ctr.get('name') == 'my-test-container', ctr
assert ctr.get('workdir') == '/tmp/aris-claude-md-test', ctr
pe = ctr.get('pre_exec')
assert isinstance(pe, list) and len(pe) == 2, ctr
print('ok')
" | grep -q ok || fail "container section not correctly parsed"
pass "container section: runtime/name/workdir/pre_exec list parsed"

# 5. Priority: CLAUDE.md > .aris/project.yaml
mkdir -p "$TMP/.aris"
cat > "$TMP/.aris/project.yaml" <<'EOF'
language: python
venue_family: ml
EOF
LANG2=$(python3 "$REPO_ROOT/tools/project_contract.py" --root "$TMP" get-language)
[[ "$LANG2" == "cpp" ]] || fail "CLAUDE.md should override YAML — got language=$LANG2"
pass "CLAUDE.md takes priority over .aris/project.yaml"

# 6. When no Project section, fall back to YAML
rm "$TMP/CLAUDE.md"
cat > "$TMP/CLAUDE.md" <<'EOF'
## Container
- runtime: docker
- name: only-container
- workdir: /tmp/x
EOF
LANG3=$(python3 "$REPO_ROOT/tools/project_contract.py" --root "$TMP" get-language)
[[ "$LANG3" == "python" ]] || fail "no Project section → should use YAML's python, got $LANG3"
SRC3=$(python3 "$REPO_ROOT/tools/project_contract.py" --root "$TMP" source)
[[ "$SRC3" == *.aris/project.yaml ]] || fail "source should report YAML, got $SRC3"
pass "without ## Project, falls back to .aris/project.yaml"

# 7. But Container section still picked up
CTR2=$(python3 "$REPO_ROOT/tools/project_contract.py" --root "$TMP" get-container)
echo "$CTR2" | grep -q "only-container" || fail "Container should be picked up even without Project section"
pass "Container section read independently of Project section"

# 8. init --target claude-md scaffolds correctly
TMP2=$(mktemp -d)
python3 "$REPO_ROOT/tools/project_contract.py" --root "$TMP2" init --target claude-md \
    --language cpp --frameworks ros2,cuda >/dev/null
[[ -f "$TMP2/CLAUDE.md" ]] || fail "init --target claude-md did not create CLAUDE.md"
grep -q "^## Project" "$TMP2/CLAUDE.md" || fail "scaffolded CLAUDE.md missing ## Project"
grep -q "^## Container" "$TMP2/CLAUDE.md" || fail "scaffolded CLAUDE.md missing ## Container"
grep -q "language: cpp" "$TMP2/CLAUDE.md" || fail "scaffolded CLAUDE.md missing language: cpp"
grep -q "frameworks: ros2, cuda" "$TMP2/CLAUDE.md" || fail "scaffolded CLAUDE.md missing frameworks line"
pass "init --target claude-md scaffolds well-formed sections"
rm -rf "$TMP2"

echo "[smoke_claude_md_contract] ALL PASS"
