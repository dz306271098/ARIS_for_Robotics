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
- review_fallback_mode: retry_then_local_critic
- resume_window_hours: 24
- max_reviewer_runtime_retries: 2
- max_auto_retries_per_stage: 3

## Notes
- Key metrics: 你关心的指标
- Constraints: 计算预算、数据限制、上线约束

## Pipeline Status
stage: init
idea: ""
contract: docs/research_contract.md
current_branch: main
baseline: ""
training_status: idle
active_tasks: []
next: bash scripts/run_unattended_mainline.sh --workflow research-pipeline --topic "你的研究方向"
