# Claude Review MCP

Bridge Codex-first ARIS workflows to the local Claude Code CLI.

## What it does

- Keeps **Codex** as the executor
- Uses **Claude Code CLI** as the external reviewer
- Exposes synchronous MCP tools:
  - `review`
  - `review_reply`
- Exposes asynchronous MCP tools for long reviewer prompts:
  - `review_start`
  - `review_reply_start`
  - `review_status`
- Accepts optional `jsonSchema` / `json_schema` arguments and forwards them to Claude CLI via `--json-schema`

The synchronous tools return a JSON string containing `threadId` and `response`.
The asynchronous start tools return a JSON string containing `jobId` and `status`, and `review_status` later returns the final `threadId` and `response`.

## Install into Codex

Prefer the repo installer when possible:

```bash
bash scripts/install_codex_claude_mainline.sh
```

This matters on proxied networks because the installer now copies the current shell's proxy env vars into the `claude-review` MCP config by default.

```bash
mkdir -p ~/.codex/mcp-servers/claude-review
cp mcp-servers/claude-review/server.py ~/.codex/mcp-servers/claude-review/server.py
codex mcp add claude-review \
  --env CLAUDE_REVIEW_MODEL='claude-opus-4-7[1m]' \
  --env CLAUDE_REVIEW_FALLBACK_MODEL='claude-opus-4-6' \
  -- python3 ~/.codex/mcp-servers/claude-review/server.py
```

If your Claude access depends on proxies and you register the MCP server manually, pass the same proxy env vars with `--env` as well. Otherwise `claude -p` may work in your shell while Codex-managed MCP calls still fail.

If your Claude Code login depends on a shell function such as `claude-aws`, use the wrapper instead:

```bash
mkdir -p ~/.codex/mcp-servers/claude-review
cp mcp-servers/claude-review/server.py ~/.codex/mcp-servers/claude-review/server.py
cp mcp-servers/claude-review/run_with_claude_aws.sh ~/.codex/mcp-servers/claude-review/run_with_claude_aws.sh
chmod +x ~/.codex/mcp-servers/claude-review/run_with_claude_aws.sh
codex mcp add claude-review \
  --env CLAUDE_REVIEW_MODEL='claude-opus-4-7[1m]' \
  --env CLAUDE_REVIEW_FALLBACK_MODEL='claude-opus-4-6' \
  -- ~/.codex/mcp-servers/claude-review/run_with_claude_aws.sh
```

## Environment Variables

- `CLAUDE_BIN`: Claude CLI path, defaults to `claude`
- `CLAUDE_REVIEW_MODEL`: primary reviewer model, defaults to `claude-opus-4-7[1m]`
- `CLAUDE_REVIEW_FALLBACK_MODEL`: fallback reviewer model for default-path calls, defaults to `claude-opus-4-6`
- `CLAUDE_REVIEW_SYSTEM`: optional default system prompt
- `CLAUDE_REVIEW_TOOLS`: Claude tools override, defaults to empty string
- `CLAUDE_REVIEW_TIMEOUT_SEC`: subprocess timeout, defaults to `600`
- Common proxy envs such as `http_proxy`, `https_proxy`, `no_proxy`, and their upper-case variants can be passed through the MCP config when Claude access depends on a proxy

## Notes

- The bridge runs Claude in non-interactive `-p` mode.
- The default reviewer chain is `claude-opus-4-7[1m]` first, then `claude-opus-4-6`.
- The fallback model is used only when the MCP call does not pass an explicit `model`. Explicit `model` values do not auto-retry.
- By default the reviewer gets **no tools**. This matches the original ARIS pattern where the external reviewer only sees the prompt context prepared by the executor.
- `threadId` is the native Claude session id and can be passed directly to `review_reply`.
- `jobId` is a bridge-local background task id stored on disk under `~/.codex/state/claude-review/jobs/` by default, so status can be resumed across MCP server restarts.
- `jsonSchema` is useful when a reviewer call needs structured JSON output without changing the narrow review-tool contract.

## Workflow boundary

This bridge is only the reviewer transport layer inside the Codex-first mainline.

- Use it for reviewer-aware stages such as `idea-creator`, `auto-review-loop`, `result-to-claim`, and paper/rebuttal review flows that explicitly call the reviewer.
- Do not treat it as the owner of `research-wiki` or `meta-optimize`. Those remain local memory and maintenance layers driven by Codex-side workflow skills.
- In the default `research-pipeline`, `deep-innovation-loop` now sits before the final `auto-review-loop` polish step when the innovation gate says more structural work is needed.

## When to use sync vs async

- Use `review` / `review_reply` for short prompts that comfortably finish within the host MCP tool timeout.
- Use `review_start` / `review_reply_start` + `review_status` for long paper or project reviews. This avoids the observed `Codex -> tools/call` timeout around 120 seconds.

## Runtime health check

Run the local runtime check before blaming the bridge:

```bash
bash scripts/check_claude_review_runtime.sh
```

This check now covers direct CLI, direct bridge, the installed `claude-review` MCP, and a host-side `Codex -> mcp__claude_review__review` call. If the shell has proxy env vars that are missing from the installed MCP config, the script tells you to reinstall with:

```bash
bash scripts/install_codex_claude_mainline.sh --reinstall
```

## Async flow

Start a long review:

```json
{
  "name": "review_start",
  "arguments": {
    "prompt": "Review this paper draft..."
  }
}
```

Example response:

```json
{
  "jobId": "5d8d0a9c5a2f4f42ae44f6f0c2d73f6f",
  "status": "queued",
  "done": false
}
```

Poll later:

```json
{
  "name": "review_status",
  "arguments": {
    "jobId": "5d8d0a9c5a2f4f42ae44f6f0c2d73f6f",
    "waitSeconds": 20
  }
}
```

When complete, `review_status` returns the same reviewer payload fields as the synchronous tools, including `threadId`, `response`, `model`, and `stop_reason`.
