# Unattended Runtime Protocol

Use this protocol when a project opts into `CODEX.md -> ## Autonomy Profile -> autonomy_mode: unattended_safe`.

## Preconditions

- Treat `CODEX.md` as the only project-level control plane.
- Respect `automation_scope`, `priority`, `allow_auto_cloud`, and `allow_auto_real_robot` as hard limits.
- Run the host-level health check before a new unattended session:

```bash
bash scripts/check_unattended_mainline.sh /path/to/project
```

## Hard Blockers

Stop and record a blocker instead of improvising when any of these are true:

- reviewer runtime is unavailable for a reviewer-gated stage
- unattended long training requires W&B but `wandb: true` / `wandb_project` is missing
- `allow_auto_cloud: false` but the next step would rent or provision new cloud GPUs
- `allow_auto_real_robot: false` but the next step needs physical robot execution
- paper-writing needs automatic illustration generation and no usable backend or existing artifact exists

## External Model Runtime

- `external_model_runtime: host_first` is the only unattended-safe runtime for external models.
- External model calls include Claude/Gemini/MiniMax review, Gemini/Paperbanana image generation, and any future third-party model API.
- Prefer host MCP bridges or host terminal checks. Do not treat Codex/bwrap sandbox CLI/API results as authoritative availability.
- If a host external model call fails, retry according to the project limit first.
- If `external_model_failure_policy: retry_then_local_fallback`, a local critic or placeholder artifact may keep the workflow moving, but update `AUTONOMY_STATE.json` with `external_model_replay_required=true` and a concrete `recovery_step`.
- Do not mark claim freeze, final paper polish, rebuttal, or required AI-generated figures as complete until the host external model replay succeeds.

## AUTONOMY_STATE Contract

`AUTONOMY_STATE.json` is the cross-workflow state anchor. Keep these keys present:

- `workflow`
- `phase`
- `status`
- `next_skill`
- `next_args`
- `blocking_reason`
- `retry_count`
- `external_model_replay_required`
- `last_heartbeat`
- `started_at`
- `updated_at`

Recommended statuses:

- `in_progress`
- `blocked`
- `completed`

Update the state at every major transition:

- before dispatch
- before long-running experiment launch
- before review / re-review
- after monitoring detects a blocker
- on final completion

## Monitoring Contract

- `watchdog` owns process health: session alive, GPU active, downloads progressing
- `training-check` owns training quality: divergence, NaN, metric collapse, plateau
- unattended long training should use both layers together

When unattended mode is active:

- register long-running training with `tools/watchdog.py`
- keep machine-readable summaries for monitor / training checks when practical
- prefer explicit blockers over silent degradation

## Recovery Rules

- Reuse workflow-native state files first:
  - `REVIEW_STATE.json`
  - `INNOVATION_STATE.json`
  - `REFINE_STATE.json`
  - `PAPER_IMPROVEMENT_STATE.json`
- Use `AUTONOMY_STATE.json` to decide which skill and arguments to resume
- If the workflow-native state says `completed`, do not restart that stage from scratch
- If `retry_count` reaches the project limit, stop and ask for operator intervention instead of spinning forever
