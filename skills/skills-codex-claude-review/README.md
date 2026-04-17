# `skills-codex-claude-review`

Thin reviewer overlay for the ARIS **Codex executor + Claude Code reviewer** mainline.

## What this package does

Install this package **after** `skills/skills-codex/` when you want:

- **Codex** to stay as the executor
- **Claude Code CLI** to become the reviewer
- the local `claude-review` MCP bridge to carry reviewer calls

This overlay rewires the predefined reviewer-aware Codex skills that previously used:

- `spawn_agent`
- `send_input`
- direct `mcp__codex__codex*` review calls

They now route through:

- `mcp__claude-review__review_start`
- `mcp__claude-review__review_reply_start`
- `mcp__claude-review__review_status`

## Current coverage

Current overrides:

- `ablation-planner`
- `auto-paper-improvement-loop`
- `auto-review-loop`
- `deep-innovation-loop`
- `experiment-bridge`
- `grant-proposal`
- `idea-creator`
- `idea-discovery`
- `idea-discovery-robot`
- `novelty-check`
- `paper-figure`
- `paper-plan`
- `paper-poster`
- `paper-slides`
- `paper-write`
- `paper-writing`
- `rebuttal`
- `research-refine`
- `research-review`
- `result-to-claim`
- `training-check`

In other words, this overlay now covers the full predefined reviewer-aware surface in `skills/skills-codex/` that is expressed through secondary-reviewer calls.

## How this fits into the mainline

This overlay does not replace the whole workflow. It only swaps the reviewer side of reviewer-aware skills.

- `Codex` still owns implementation, file edits, experiment execution, and local workflow maintenance.
- `deep-innovation-loop` still remains Codex-owned at the execution layer, but its external diagnosis, design, and audit review calls are now also routed through this Claude overlay.
- `research-wiki` remains a local memory layer updated by the executor-side skills.
- `meta-optimize` remains a post-milestone maintenance loop. It analyzes artifacts after work has accumulated; it is not a reviewer bridge feature.

That separation is intentional: Claude is the reviewer, not the workflow orchestrator.

The mainline this overlay attaches to is now profile-routed through `CODEX.md -> ## Execution Profile`, so the same reviewer path can stay attached to the existing `python_ml` workflow plus the newer `cpp_algorithm` (`cpu_benchmark` / `cpu_cuda_mixed`) and `robotics_slam` (`slam_offline`) workflows.

## Install

1. Install the base Codex pack first:

```bash
mkdir -p ~/.codex/skills
cp -a skills/skills-codex/* ~/.codex/skills/
```

2. Install this reviewer overlay second:

```bash
cp -a skills/skills-codex-claude-review/* ~/.codex/skills/
```

3. Register the local reviewer bridge:

```bash
mkdir -p ~/.codex/mcp-servers/claude-review
cp mcp-servers/claude-review/server.py ~/.codex/mcp-servers/claude-review/server.py
codex mcp add claude-review -- python3 ~/.codex/mcp-servers/claude-review/server.py
```

If your Claude access depends on proxies, prefer the repo installer instead:

```bash
bash scripts/install_codex_claude_mainline.sh --reinstall
```

The installer now copies common proxy env vars from the current shell into the `claude-review` MCP config. If you register the MCP server manually, you need to pass the same proxy env vars with `--env` or Codex-managed reviewer calls may still fail.

If your Claude login depends on a wrapper such as `claude-aws`, use:

```bash
cp mcp-servers/claude-review/run_with_claude_aws.sh ~/.codex/mcp-servers/claude-review/run_with_claude_aws.sh
chmod +x ~/.codex/mcp-servers/claude-review/run_with_claude_aws.sh
codex mcp add claude-review -- ~/.codex/mcp-servers/claude-review/run_with_claude_aws.sh
```

Optional reviewer model override:

```bash
codex mcp remove claude-review
codex mcp add claude-review \
  --env CLAUDE_REVIEW_MODEL='claude-opus-4-7[1m]' \
  --env CLAUDE_REVIEW_FALLBACK_MODEL='claude-opus-4-6' \
  -- python3 ~/.codex/mcp-servers/claude-review/server.py
```

## Notes

- Prefer the async `review_start` / `review_reply_start` + `review_status` flow for long prompts.
- The default reviewer chain is `claude-opus-4-7[1m]` first, then `claude-opus-4-6`.
- The fallback model is used only when the MCP call does not pass an explicit `model`.
- `CODEX.md` is the recommended project config name for this path.
- `CODEX.md` is the only mainline project config name for this path.
- `research-wiki` and `meta-optimize` are intentionally inherited from the base Codex pack rather than overridden here.

## Regenerate

Regenerate the overlay after upstream Codex skill changes:

```bash
python3 tools/generate_codex_claude_review_overrides.py
```
