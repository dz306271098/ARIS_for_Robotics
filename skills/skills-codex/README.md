# `skills-codex`

Codex-native ARIS skill pack.

## What this package is

This directory is now the **main Codex executor pack** for ARIS. Install it into `~/.codex/skills/` and use it as the base layer for:

- pure Codex execution
- Codex + Claude review via `skills-codex-claude-review/`
- Codex + Gemini review via `skills-codex-gemini-review/`

It mirrors the current repository skill surface that is practical to run from Codex, including the newer support skills that were previously missing from the Codex pack:

- `deep-innovation-loop`
- `meta-optimize`
- `research-wiki`
- `semantic-scholar`
- `system-profile`
- `vast-gpu`
- `training-check`
- `result-to-claim`
- `ablation-planner`
- `rebuttal`

`shared-references/` is included as a support directory and is intentionally not a callable skill.

All code-writing execution workflows now share two hard protocols:

- `Mandatory Test Gate` — after code changes, pass module tests plus a workflow smoke test before deploy or re-review
- `Reviewer Resolution Protocol` — disputed reviewer findings must go back through the same review thread until they converge
- `Unattended Runtime Protocol` — `CODEX.md -> ## Autonomy Profile`, `AUTONOMY_STATE.json`, watchdog, and W&B govern long-running unattended-safe execution

## Mainline workflow embedding

These newer support skills are not sidecars anymore. In the current mainline they fit together like this:

- `research-wiki` is the long-horizon memory layer. Initialize it once after `CODEX.md` and `RESEARCH_BRIEF.md` are stable, then let `/research-lit`, `/idea-creator`, and `/result-to-claim` keep it fresh.
- `deep-innovation-loop` is now part of the default `/research-pipeline` method-evolution path. The practical chain is:
  `/idea-discovery -> /experiment-bridge -> /result-to-claim -> /deep-innovation-loop? -> /auto-review-loop -> /result-to-claim -> /paper-writing`
- `meta-optimize` is not part of fragile experiment execution. Use it after milestones to improve the harness based on artifacts such as `AUTO_REVIEW.md`, `innovation-logs/`, `refine-logs/`, `paper/`, `rebuttal/`, and `CODEX.md`.

In other words:

- `research-wiki` = memory layer
- `deep-innovation-loop` = mainline evolution stage
- `meta-optimize` = maintenance layer

## Install

```bash
mkdir -p ~/.codex/skills
cp -a skills/skills-codex/* ~/.codex/skills/
```

If you use a reviewer overlay, always install this base package first and then copy the overlay on top.

## Project config naming

For Codex-first usage, use a project-level `CODEX.md` as the primary config and status file.

- `CODEX.md` is the only mainline project config name
- mainline skills, tools, and docs in this package are expected to read `CODEX.md`

## Scope boundary

This package migrates the **skill files and support references**, not the whole runtime environment.

You still need to provide and configure your own:

- Python / LaTeX / GPU / SSH environment
- MCP servers
- API keys or CLI logins
- project-specific `CODEX.md` / data / codebase
