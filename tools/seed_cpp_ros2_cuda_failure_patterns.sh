#!/usr/bin/env bash
# seed_cpp_ros2_cuda_failure_patterns.sh — Populate a research-wiki with the
# 15 canonical failure patterns for C++ / ROS2 / CUDA research (ARIS v2.2+).
#
# Usage:
#   bash tools/seed_cpp_ros2_cuda_failure_patterns.sh <wiki-root>
#
# Each pattern is seeded with status=active, tagged by domain, and linked to a
# synthetic source node ("paper:aris-v22-seeds") so the wiki graph stays consistent.
set -euo pipefail

WIKI="${1:?usage: $0 <wiki-root>}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RW="$SCRIPT_DIR/research_wiki.py"

if [[ ! -d "$WIKI" ]]; then
  echo "Initializing wiki at $WIKI"
  python3 "$RW" init "$WIKI"
fi

# Create the synthetic seed paper if missing
if [[ ! -f "$WIKI/papers/aris-v22-seeds.md" ]]; then
  python3 "$RW" ingest_paper "$WIKI" \
    --title "ARIS v2.2 C++/ROS2/CUDA Domain Seeds" \
    --authors "ARIS maintainers" --year 2026 \
    --venue "ARIS internal" \
    --thesis "Canonical failure anti-patterns for C++, ROS2, and CUDA research." \
    --tags aris,seed,domains \
    >/dev/null
fi

FROM="paper:aris-v22-seeds"

upsert() {
  local slug="$1" name="$2" gen="$3" tags="$4"
  python3 "$RW" upsert_failure_pattern "$WIKI" "$slug" \
    --from "$FROM" \
    --name "$name" \
    --generalized "$gen" \
    --tags "$tags" \
    --status active >/dev/null
  echo "  ✓ seeded $slug"
}

echo "Seeding 15 failure patterns..."

# ─── C++ (6) ───────────────────────────────────────────────────────────────
upsert ub-exploit-compiler-optimization \
  "UB exploited by compiler optimization" \
  "Undefined behavior in the source that the optimizer silently leverages, flipping program behavior between -O0 and -O3. Invisible without UBSan / comparison builds." \
  "cpp,ub,compiler"

upsert hidden-asymptotic-constant \
  "Hidden asymptotic constant" \
  "An O(f(n)) algorithm with a prohibitive hidden constant (often > 2^20) that is outperformed in practice by an asymptotically worse but constant-friendly algorithm across typical input sizes." \
  "cpp,theory,complexity"

upsert cache-thrash-false-sharing \
  "Cache thrashing from false sharing" \
  "Multi-threaded code where independent variables share a cache line; contention serializes what should be parallel, scaling anti-correlates with core count." \
  "cpp,concurrency,cache"

upsert numerical-instability-catastrophic-cancellation \
  "Catastrophic cancellation in floating-point subtraction" \
  "Subtraction of nearly-equal floats loses all significant digits; the result appears within bounds but is numerically meaningless, usually detected only by comparison with higher-precision reference." \
  "cpp,numerical,floating-point"

upsert race-condition-data-race \
  "Data race in concurrent algorithm" \
  "Two threads access the same memory location without synchronization and at least one writes. Intermittent wrong results; detectable by TSan under load but hidden in single-thread tests." \
  "cpp,concurrency,race"

upsert memory-fragmentation-allocator-pressure \
  "Memory-fragmentation-driven allocator pressure" \
  "Frequent alloc/free cycles with varied sizes fragment the heap; wall time is dominated by malloc/free rather than algorithmic work. Visible in perf as libc allocator hotspots." \
  "cpp,memory,allocator"

# ─── ROS2 (4) ──────────────────────────────────────────────────────────────
upsert ros2-qos-profile-mismatch \
  "ROS2 QoS profile mismatch" \
  "Publisher and subscriber declare incompatible QoS (e.g., RELIABLE pub + BEST_EFFORT sub). DDS silently drops connections or messages; appears as missing data but nodes look healthy." \
  "ros2,qos,discovery"

upsert ros2-callback-group-deadlock \
  "ROS2 callback-group deadlock" \
  "Two mutually-exclusive callback groups each blocking on a service provided by the other create a deadlock; executor hangs with no error message. Detectable only by liveness probe." \
  "ros2,executor,concurrency"

upsert ros2-tf-tree-race \
  "ROS2 TF tree race (stale transforms)" \
  "Consumer performs TF lookup before publisher finishes initializing /tf_static; intermittent TF_OLD_DATA or ExtrapolationException on startup. Causes spurious control errors." \
  "ros2,tf,startup"

upsert ros2-dds-discovery-failure \
  "ROS2 DDS discovery storm / failure" \
  "DDS discovery protocol generates excessive traffic on node churn or fails to complete across network partitions; nodes appear not to discover each other despite being live. Distro-specific." \
  "ros2,dds,discovery"

# ─── CUDA (5) ──────────────────────────────────────────────────────────────
upsert cuda-warp-divergence-perf \
  "CUDA warp divergence perf" \
  "Threads within a warp take different control-flow branches, serializing execution; visible as low warp_execution_efficiency in Nsight Compute. Hidden when benchmarks use aligned test inputs." \
  "cuda,performance,warp"

upsert cuda-shared-memory-bank-conflict \
  "CUDA shared-memory bank conflict" \
  "Multiple threads in a warp access distinct words mapped to the same shared-memory bank, serializing access; costs 32x throughput hit. Often mistaken for memory-bound pattern." \
  "cuda,memory,shared-memory"

upsert cuda-unaligned-global-access \
  "CUDA unaligned global-memory access" \
  "Thread block accesses DRAM at non-128B-aligned offsets; coalescing fails, transactions multiply. Detectable via Nsight memcheck / low dram efficiency." \
  "cuda,memory,coalescing"

upsert cuda-register-pressure-spill \
  "CUDA register-pressure spill" \
  "Kernel exceeds register budget per thread; nvcc spills to local memory (actually DRAM), causing 10-100x slowdowns not visible in source. Report from --ptxas-options=-v." \
  "cuda,registers,performance"

upsert cuda-async-copy-race \
  "CUDA async-copy race" \
  "cudaMemcpyAsync or cudaMemcpy2DAsync used without matching stream/event synchronization; kernel reads from buffer before copy completes, producing stale or partially-initialized values." \
  "cuda,concurrency,async"

echo "Done. 15 failure patterns seeded under $WIKI/failures/"
