# Codex + Claude Review Guide

This is the **mainline ARIS path**:

- **Codex** executes
- **Claude Code CLI** reviews
- the local `claude-review` MCP bridge transports reviewer calls

If you are starting fresh on ARIS today, use this path first.

## Architecture

- Base executor pack: `skills/skills-codex/`
- Reviewer overlay: `skills/skills-codex-claude-review/`
- Reviewer bridge: `mcp-servers/claude-review/`

Install order matters:

1. install `skills/skills-codex/*`
2. install `skills/skills-codex-claude-review/*`
3. register `claude-review` MCP

`scripts/install_codex_claude_mainline.sh` enforces that order automatically.

## Install

```bash
git clone https://github.com/wanshuiyin/Auto-claude-code-research-in-sleep.git
cd Auto-claude-code-research-in-sleep
bash scripts/install_codex_claude_mainline.sh
```

If your Claude login depends on a wrapper such as `claude-aws`, use:

```bash
bash scripts/install_codex_claude_mainline.sh --reinstall --use-aws-wrapper
```

Optional reviewer model override:

```bash
bash scripts/install_codex_claude_mainline.sh --reinstall --review-model claude-opus-4-1
```

Uninstall:

```bash
bash ~/.codex/.aris/codex-claude-mainline/uninstall_codex_claude_mainline.sh
```

That local uninstall helper is copied during install and only rolls back paths tracked by the ARIS install manifest.

## Verify

1. Check MCP registration:

```bash
codex mcp list
```

2. Check Claude CLI login:

```bash
claude -p "Reply with exactly READY" --output-format json --tools ""
```

3. Start Codex in your project:

```bash
codex -C /path/to/your/project
```

Maintainer smoke test:

```bash
bash scripts/smoke_test_codex_claude_mainline.sh
```

## Coverage

The overlay now covers the predefined reviewer-aware Codex skills that previously depended on a secondary Codex reviewer or direct `mcp__codex__codex*` review calls:

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

## Workflow embedding

This mainline should be understood as a layered workflow, not as "Claude reviews everything."

- `Codex` owns execution, implementation, experiment launches, local file updates, and workflow state.
- `Claude Code` owns the reviewer role for the predefined reviewer-aware skills routed through `claude-review`.
- `research-wiki` is the long-term memory layer. Initialize it once, then let `/research-lit`, `/idea-creator`, and `/result-to-claim` keep it synchronized.
- `deep-innovation-loop` is now inside the default `/research-pipeline` path. The practical sequence is:
  `/idea-discovery -> implement -> /run-experiment -> innovation gate -> /deep-innovation-loop? -> /auto-review-loop`
- Within `deep-innovation-loop`, Codex still owns implementation and experiments, while the external diagnosis/design/audit checkpoints now also flow through the Claude reviewer overlay.
- `meta-optimize` is a maintenance loop after milestones, not a step in fragile experiment execution. Run it once artifacts such as `AUTO_REVIEW.md`, `innovation-logs/`, `refine-logs/`, `paper/`, or `rebuttal/` exist.

This means the bridge boundary is narrow on purpose: Claude reviews reviewer-facing stages, while Codex keeps ownership of the main execution path and maintenance machinery.

## Project Config

Prefer a project-level `CODEX.md` for:

- executor instructions
- environment notes
- `## Pipeline Status`

`CODEX.md` is the only mainline project config name for this path.

## Async Reviewer Flow

For long paper or project reviews, prefer:

- `review_start`
- `review_reply_start`
- `review_status`

The call chain is:

`Codex -> claude-review MCP -> local Claude CLI -> Claude backend`

The extra local CLI hop is the main reason long synchronous reviewer calls are more likely to hit the host MCP timeout.

## Structured Output

The `claude-review` bridge now also accepts optional `jsonSchema` / `json_schema` arguments and forwards them to Claude CLI via `--json-schema`. Use this when a skill needs structured reviewer output.

## Maintenance

Regenerate the overlay after upstream Codex skill updates:

```bash
python3 tools/generate_codex_claude_review_overrides.py
```
