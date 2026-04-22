# Project Overview

## Research Direction
- Topic: 你的研究方向
- Target venue: ICLR / ICML / NeurIPS / CVPR / ACL / AAAI / IEEE_JOURNAL / IEEE_CONF
- Main baseline: 你的主基线

## GPU Configuration
- gpu: remote
- ssh_alias: your-server
- conda_env: research
- code_dir: ~/your-project
- wandb: true
- wandb_project: your-project

## Execution Profile
- project_stack: python_ml
- build_system: python
- runtime_profile: training
- build_dir: build
- build_type:
- cmake_preset:
- test_backend: pytest
- benchmark_backend: none
- artifact_roots: build,results,wandb,monitoring,profiles

## CUDA Profile
- cuda_enabled: false
- cuda_architectures:
- cuda_toolkit_root:
- profiling_backend: none

## Robotics Profile
- robotics_domain: slam_perception
- data_backend: dataset
- benchmark_suite:
- sensor_stack:
- ground_truth_type:
- ros_distro: none

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
- require_watchdog: true
- require_wandb_for_unattended_training: true
- paper_illustration: auto
- notifications: push_only
- reviewer_provider: claude
- review_fallback_mode: retry_then_local_critic
- external_model_runtime: host_first
- external_model_failure_policy: retry_then_local_fallback
- external_model_replay_required: false
- resume_window_hours: 24
- max_reviewer_runtime_retries: 2
- max_auto_retries_per_stage: 3

## Notes
- Key metrics: 你关心的指标
- Constraints: 计算预算、数据限制、上线约束
- C++ benchmark projects: `project_stack: cpp_algorithm` + `build_system: cmake` + `runtime_profile: cpu_benchmark` + `test_backend: ctest`
- CPU+CUDA projects: `project_stack: cpp_algorithm` + `runtime_profile: cpu_cuda_mixed` + `cuda_enabled: true`，并补齐 `profiling_backend`
- Robotics / SLAM projects: `project_stack: robotics_slam` + `runtime_profile: slam_offline`；plain CMake 优先，ROS2 时再改 `build_system: cmake_ros2`

## Pipeline Status
stage: init
idea: ""
contract: docs/research_contract.md
current_branch: main
baseline: ""
training_status: idle
active_tasks: []
next: bash scripts/run_unattended_mainline.sh --workflow research-pipeline --topic "你的研究方向"
