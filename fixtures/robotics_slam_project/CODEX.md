# Project Overview

## Research Direction
- Topic: Offline SLAM / perception benchmarking fixture
- Target venue: IEEE_CONF
- Main baseline: ORB-SLAM style baseline

## GPU Configuration
- gpu: local
- code_dir: .

## Execution Profile
- project_stack: robotics_slam
- build_system: cmake
- runtime_profile: slam_offline
- build_dir: build
- build_type: Release
- cmake_preset:
- test_backend: ctest
- benchmark_backend: trajectory_eval
- artifact_roots: build,results,monitoring,profiles

## CUDA Profile
- cuda_enabled: false
- cuda_architectures:
- cuda_toolkit_root:
- profiling_backend: none

## Robotics Profile
- robotics_domain: slam_perception
- data_backend: rosbag
- benchmark_suite: tum_rgbd
- sensor_stack: stereo + imu
- ground_truth_type: trajectory
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
- require_watchdog: false
- require_wandb_for_unattended_training: true
- paper_illustration: auto
- notifications: off
- review_fallback_mode: retry_then_local_critic
- resume_window_hours: 24
- max_reviewer_runtime_retries: 2
- max_auto_retries_per_stage: 3

## Notes
- Key metrics: ATE, RPE, tracking rate, latency, FPS, mAP
- Constraints: offline rosbag fixture for smoke tests only
