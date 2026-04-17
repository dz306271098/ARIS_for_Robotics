# Project Overview

## Research Direction
- Topic: Benchmark-grounded C++ algorithm evaluation
- Target venue: IEEE_CONF
- Main baseline: vector_sum baseline

## GPU Configuration
- gpu: local
- code_dir: .

## Execution Profile
- project_stack: cpp_algorithm
- build_system: cmake
- runtime_profile: cpu_benchmark
- build_dir: build
- build_type: Release
- cmake_preset:
- test_backend: ctest
- benchmark_backend: custom_cli
- artifact_roots: build,results,monitoring

## Research Intelligence Profile
- innovation_mode: high_innovation
- topic_router: auto
- literature_depth: principle_graph
- idea_portfolio_size: 3
- shadow_route_count: 1

## Autonomy Profile
- autonomy_mode: unattended_safe
- automation_scope: core_mainline
- priority: quality_stability
- allow_auto_cloud: false
- allow_auto_real_robot: false
- require_watchdog: false
- require_wandb_for_unattended_training: true
- paper_illustration: auto
- notifications: off
- review_fallback_mode: retry_then_local_critic
- resume_window_hours: 24
- max_reviewer_runtime_retries: 2
- max_auto_retries_per_stage: 3

## Notes
- Key metrics: correctness, runtime, memory, scaling
- Constraints: local CPU benchmark fixture for smoke tests
