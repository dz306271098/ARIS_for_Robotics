#!/usr/bin/env python3
"""Generate Gemini-review overrides for the upstream Codex-native skills."""

from __future__ import annotations

import ast
import json
import re
import shutil
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SRC_ROOT = REPO_ROOT / "skills" / "skills-codex"
DEST_ROOT = REPO_ROOT / "skills" / "skills-codex-gemini-review"

TARGET_SKILLS = [
    "ablation-planner",
    "experiment-bridge",
    "deep-innovation-loop",
    "idea-creator",
    "idea-discovery",
    "idea-discovery-robot",
    "research-review",
    "novelty-check",
    "research-refine",
    "auto-review-loop",
    "grant-proposal",
    "paper-plan",
    "paper-figure",
    "paper-poster",
    "paper-slides",
    "paper-write",
    "paper-writing",
    "auto-paper-improvement-loop",
    "result-to-claim",
    "rebuttal",
    "training-check",
]

FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---\n?", re.DOTALL)
DESCRIPTION_LINE_RE = re.compile(r"^(description:\s*)(.+)$", re.MULTILINE)
SPAWN_BLOCK_RE = re.compile(r"```(?:yaml|text)?\nspawn_agent:\n([\s\S]*?)```")
SEND_BLOCK_RE = re.compile(r"```(?:yaml|text)?\nsend_input:\n([\s\S]*?)```")

OVERRIDE_NOTE = (
    "> Override for Codex users who want **Gemini CLI**, not a second Codex agent, "
    "to act as the reviewer. Install this package **after** `skills/skills-codex/*`."
)

REVIEWER_LINE = (
    "- **REVIEWER_MODEL = `gemini-review`** — Gemini reviewer invoked through the "
    "local `gemini-review` MCP bridge. This bridge is CLI-first; set "
    "`GEMINI_REVIEW_MODEL` if you need a specific Gemini CLI model override."
)

PREREQ_BLOCK = """## Prerequisites

- Install the base Codex-native skills first: copy `skills/skills-codex/*` into `~/.codex/skills/`.
- Then install this overlay package: copy `skills/skills-codex-gemini-review/*` into `~/.codex/skills/` and allow it to overwrite the same skill names.
- Register the local reviewer bridge:
  ```bash
  codex mcp add gemini-review --env GEMINI_REVIEW_BACKEND=cli --env GEMINI_REVIEW_MODEL=gemini-3.1-pro-preview -- python3 ~/.codex/mcp-servers/gemini-review/server.py
  ```
- This gives Codex access to `mcp__gemini_review__review_start`, `mcp__gemini_review__review_reply_start`, and `mcp__gemini_review__review_status`.
""".strip()

GEMINI_REVIEW_TOOLS = (
    "mcp__gemini_review__review_start",
    "mcp__gemini_review__review_reply_start",
    "mcp__gemini_review__review_status",
)


def extract_field(frontmatter: str, field: str) -> str:
    pattern = re.compile(rf"^{re.escape(field)}:\s*(.+)$", re.MULTILINE)
    match = pattern.search(frontmatter)
    if not match:
        return ""
    value = match.group(1).strip()
    if (value.startswith('"') and value.endswith('"')) or (value.startswith("'") and value.endswith("'")):
        try:
            value = ast.literal_eval(value)
        except (SyntaxError, ValueError):
            value = value[1:-1]
    return value


def normalize_description(text: str) -> str:
    text = text or "Gemini-review override for a Codex-native ARIS skill."
    text = text.replace("A secondary Codex agent", "A Gemini reviewer via gemini-review MCP")
    text = text.replace("A secondary Codex reviewer", "A Gemini reviewer via gemini-review MCP")
    text = text.replace("from GPT using a secondary Codex reviewer agent", "from Gemini via gemini-review MCP")
    text = text.replace("GPT using a secondary Codex agent", "Gemini via gemini-review MCP")
    text = text.replace("using a secondary Codex reviewer agent", "using Gemini CLI via gemini-review MCP")
    text = text.replace("secondary Codex reviewer", "Gemini reviewer")
    text = text.replace("using a secondary Codex agent", "using Gemini CLI via gemini-review MCP")
    text = text.replace("secondary Codex agent", "Gemini reviewer via gemini-review MCP")
    text = text.replace("via iterative GPT-5.4 review", "via iterative Gemini review through gemini-review MCP")
    text = text.replace("via GPT-5.4 xhigh review", "via Gemini CLI review through gemini-review MCP")
    return text


def yaml_double_quoted_scalar(text: str) -> str:
    return json.dumps(text, ensure_ascii=False)


def ensure_allowed_tools(frontmatter: str) -> str:
    pattern = re.compile(r"^(allowed-tools:\s*)(.+)$", re.MULTILINE)
    match = pattern.search(frontmatter)
    if not match:
        return frontmatter

    existing = [item.strip() for item in match.group(2).split(",")]
    tools = [tool for tool in existing if tool]
    for tool in GEMINI_REVIEW_TOOLS:
        if tool not in tools:
            tools.append(tool)
    return pattern.sub(lambda item: f"{item.group(1)}{', '.join(tools)}", frontmatter, count=1)


def rewrite_frontmatter(frontmatter: str) -> str:
    description = normalize_description(extract_field(frontmatter, "description"))
    description_literal = yaml_double_quoted_scalar(description)

    if DESCRIPTION_LINE_RE.search(frontmatter):
        frontmatter = DESCRIPTION_LINE_RE.sub(
            lambda match: f"{match.group(1)}{description_literal}",
            frontmatter,
            count=1,
        )
    else:
        lines = frontmatter.splitlines()
        inserted = False
        for index, line in enumerate(lines):
            if line.startswith("name:"):
                lines.insert(index + 1, f"description: {description_literal}")
                inserted = True
                break
        if not inserted:
            lines.insert(0, f"description: {description_literal}")
        frontmatter = "\n".join(lines)

    frontmatter = frontmatter.replace("mcp__codex__codex-reply", "mcp__gemini_review__review_reply_start")
    frontmatter = frontmatter.replace("mcp__codex__codex", "mcp__gemini_review__review_start")
    if (
        "allowed-tools:" in frontmatter
        and "mcp__gemini_review__review_start" in frontmatter
        and "mcp__gemini_review__review_status" not in frontmatter
    ):
        frontmatter = frontmatter.replace(
            "mcp__gemini_review__review_reply_start",
            "mcp__gemini_review__review_reply_start, mcp__gemini_review__review_status",
            1,
        )

    rewritten_description = extract_field(frontmatter, "description")
    if rewritten_description != description:
        raise ValueError(
            "Gemini overlay frontmatter description round-trip mismatch: "
            f"expected {description!r}, got {rewritten_description!r}"
        )
    return ensure_allowed_tools(frontmatter)


def rewrite_spawn_block(match: re.Match[str]) -> str:
    lines = match.group(1).splitlines()
    out = ["```", "mcp__gemini_review__review_start:"]
    for line in lines:
        stripped = line.strip()
        if not stripped:
            out.append(line)
            continue
        if stripped.startswith("model:") or stripped.startswith("reasoning_effort:"):
            continue
        if stripped.startswith("message:"):
            out.append(line.replace("message:", "prompt:", 1))
            continue
        out.append(line)
    out.append("```")
    return "\n".join(out)


def rewrite_send_block(match: re.Match[str]) -> str:
    lines = match.group(1).splitlines()
    out = ["```", "mcp__gemini_review__review_reply_start:"]
    for line in lines:
        stripped = line.strip()
        if not stripped:
            out.append(line)
            continue
        if stripped.startswith("model:") or stripped.startswith("reasoning_effort:"):
            continue
        if stripped.startswith("id:"):
            out.append(line.replace("id:", "threadId:", 1))
            continue
        if stripped.startswith("target:"):
            out.append(line.replace("target:", "threadId:", 1))
            continue
        if stripped.startswith("message:"):
            out.append(line.replace("message:", "prompt:", 1))
            continue
        out.append(line)
    out.append("```")
    return "\n".join(out)


def append_async_notes(text: str) -> str:
    note = (
        "After this review-start or review-reply call, immediately save the returned `jobId` and poll "
        "`mcp__gemini_review__review_status` with a bounded `waitSeconds` until "
        "`done=true`. Treat the completed status payload's `response` as the "
        "reviewer output, and save the completed `threadId` for any follow-up round."
    )

    def repl(match: re.Match[str]) -> str:
        block = match.group(0)
        if note in block:
            return block
        return f"{block}\n\n{note}"

    return re.sub(
        r"```(?:yaml|text)?\n(?:mcp__gemini_review__review_start:|mcp__gemini_review__review_reply_start:)[\s\S]*?```",
        repl,
        text,
    )


def transform_body(text: str) -> str:
    text = text.replace("secondary Codex agent (xhigh reasoning)", "Gemini reviewer via `gemini-review` MCP")
    text = text.replace("secondary Codex agent", "Gemini reviewer via `gemini-review` MCP")
    text = text.replace("secondary Codex reviewer", "Gemini reviewer")
    text = text.replace("Secondary Codex", "Gemini Reviewer")
    text = text.replace("Codex/GPT-5.4", "Codex/Gemini reviewer")
    text = text.replace("Codex reviewer agent", "Gemini reviewer")
    text = text.replace("Codex reviewer", "Gemini reviewer")
    text = text.replace("via a Gemini reviewer via `gemini-review` MCP (xhigh reasoning)", "via `gemini-review` MCP (high-rigor review)")
    text = text.replace("GPT-5.4 xhigh", "Gemini CLI review")
    text = text.replace("GPT-5.4's", "the Gemini reviewer's")
    text = text.replace("GPT-5.4 reviews", "Gemini reviewer checks")
    text = text.replace("GPT-5.4 review", "Gemini review")
    text = text.replace("via Codex MCP", "via the local `gemini-review` MCP bridge")
    text = text.replace("using Codex MCP", "using the local `gemini-review` MCP bridge")
    text = text.replace("Codex MCP for", "`gemini-review` MCP for")
    text = text.replace("Send the full paper text to GPT-5.4 xhigh:", "Send the full paper text to Gemini through `gemini-review`:")
    text = text.replace("Send the complete outline to GPT-5.4 xhigh for feedback:", "Send the complete outline to Gemini for feedback:")
    text = text.replace("Call REVIEWER_MODEL via `spawn_agent` (`spawn_agent`) with xhigh reasoning:", "Call REVIEWER_MODEL via `mcp__gemini_review__review_start` with high-rigor review:")
    text = text.replace("Send a detailed prompt with xhigh reasoning:", "Send a detailed prompt with high-rigor review:")
    text = text.replace("Use `send_input` with the returned agent id to continue the conversation:", "Use `mcp__gemini_review__review_reply_start` with the saved completed `threadId`, then poll `mcp__gemini_review__review_status` with the returned `jobId` until `done=true` to continue the conversation:")
    text = text.replace("If this is round 2+, use `send_input` with the saved agent id to maintain continuity.", "If this is round 2+, use `mcp__gemini_review__review_reply_start` with the saved completed `threadId`, then poll `mcp__gemini_review__review_status` with the returned `jobId` until `done=true` to maintain continuity.")
    text = text.replace("Save the agent id for Round 2.", "Save the returned `jobId`, poll `mcp__gemini_review__review_status` until `done=true`, then save the completed `threadId` for Round 2.")
    text = text.replace("Save agent id from first call, use `send_input` for subsequent rounds", "Save the completed `threadId` from the first `mcp__gemini_review__review_status` result, then use `mcp__gemini_review__review_reply_start` plus `mcp__gemini_review__review_status` for subsequent rounds")
    text = text.replace("Document the agent id for potential future resumption", "Document the completed `threadId` for potential future resumption")
    text = text.replace("Use `send_input` with the saved agent id:", "Use `mcp__gemini_review__review_reply_start` with the saved completed `threadId`:")
    text = text.replace("Send the full proposal to GPT-5.4 for", "Send the full proposal to Gemini through `gemini-review` for")
    text = text.replace("Send the revised proposal back to GPT-5.4 in the **same agent**:", "Send the revised proposal back to Gemini through `gemini-review` in the **same reviewer thread**:")
    text = text.replace("Send figure descriptions and captions to GPT-5.4 for review:", "Send figure descriptions and captions to Gemini through `gemini-review` for review:")
    text = text.replace("implements → GPT-5.4 review →", "implements → Gemini review →")
    text = text.replace("use `send_input` for Round 2 to maintain conversation context", "use `mcp__gemini_review__review_reply_start` plus `mcp__gemini_review__review_status` for Round 2 to maintain conversation context")
    text = text.replace("**CRITICAL: Save the `agent_id`** from this call for all later rounds.", "**CRITICAL: Save the returned `jobId`**, poll `mcp__gemini_review__review_status` until `done=true`, then save the completed `threadId` from the status result for all later rounds.")
    text = text.replace("- **ALWAYS use `reasoning_effort: xhigh`** for all Codex review calls.", "- **Always ask the Gemini reviewer for strict, high-rigor feedback** in every review round.")
    text = text.replace("- **Save `agent_id` from Phase 2** and use `send_input` for later rounds.", "- **Save the completed `threadId` from Phase 2** and use `mcp__gemini_review__review_reply_start` plus `mcp__gemini_review__review_status` for later rounds.")
    text = text.replace("- **Use `send_input`** for Round 2 to maintain conversation context", "- **Use `mcp__gemini_review__review_reply_start` plus `mcp__gemini_review__review_status`** for Round 2 to maintain conversation context")
    text = text.replace("Use GPT-5.4 via `send_input` (same agent):", "Use Gemini via `mcp__gemini_review__review_reply_start` with the saved completed `threadId`:")
    text = text.replace(
        "If `/research-review` is invoked (preferred), it handles the external review internally. If you run the reviewer directly, use `spawn_agent` for Round 1 and `send_input` for follow-up rounds.",
        "If `/research-review` is invoked (preferred), it handles the external review internally. If you run the reviewer directly, use `mcp__gemini_review__review_start` for Round 1 and `mcp__gemini_review__review_reply_start` plus `mcp__gemini_review__review_status` for follow-up rounds.",
    )
    text = text.replace(
        "If continuity helps, reuse the same reviewer agent via `send_input`",
        "If continuity helps, reuse the same reviewer thread via `mcp__gemini_review__review_reply_start` plus `mcp__gemini_review__review_status`",
    )
    text = text.replace("`~/.claude/feishu.json`", "`~/.codex/feishu.json`")
    text = text.replace("GPT-5.4 responses", "Gemini reviewer responses")
    text = text.replace("Full verbatim response from GPT-5.4", "Full verbatim response from Gemini reviewer")
    text = text.replace("Reviewer feedback: [key points from GPT-5.4]", "Reviewer feedback: [key points from Gemini reviewer]")
    text = text.replace("Review score: [summary from GPT-5.4]", "Review score: [summary from Gemini reviewer]")
    text = text.replace("GPT-5.4", "Gemini reviewer")
    text = text.replace("Claude + Gemini", "Gemini CLI review")
    text = text.replace("Claude visual assessment", "Gemini visual assessment through `gemini-review`")
    text = text.replace("Claude reads", "Gemini reviewer reads")
    text = text.replace("Claude reviews", "Gemini reviewer reviews")
    text = text.replace("Claude review", "Gemini review")
    text = text.replace("same agent", "same reviewer thread")
    text = text.replace("same dialogue", "same reviewer thread")
    text = text.replace("use `send_input` only when", "use `mcp__gemini_review__review_reply_start` plus `mcp__gemini_review__review_status` only when")
    text = text.replace("reuse the same reviewer thread via `send_input`", "reuse the same reviewer thread via `mcp__gemini_review__review_reply_start` plus `mcp__gemini_review__review_status`")
    text = text.replace("via `send_input`", "via `mcp__gemini_review__review_reply_start` plus `mcp__gemini_review__review_status`")
    text = text.replace("use `send_input`", "use `mcp__gemini_review__review_reply_start` plus `mcp__gemini_review__review_status`")
    text = text.replace("reviewer agent id", "completed reviewer `threadId`")
    text = text.replace("diagnosis agent id", "completed diagnosis `threadId`")
    text = text.replace("innovation-design agent id", "completed innovation-design `threadId`")
    text = text.replace("implementation-audit agent id", "completed implementation-audit `threadId`")
    text = text.replace("agent id", "completed `threadId`")
    text = text.replace("`agent_id`", "`thread_id`")
    text = text.replace('"agent_id"', '"thread_id"')
    text = text.replace("ALWAYS use `reasoning_effort: xhigh` for reviews", "Always ask the Gemini reviewer for strict, high-rigor feedback.")
    text = text.replace("ALWAYS use `reasoning_effort: xhigh` for maximum reasoning depth", "Always ask the Gemini reviewer for strict, high-rigor feedback.")
    text = text.replace("mcp__codex__codex-reply", "mcp__gemini_review__review_reply_start")
    text = text.replace("mcp__codex__codex", "mcp__gemini_review__review_start")
    text = text.replace(
        "If `mcp__gemini_review__review_start` is not available (no OpenAI API key), skip external review and proceed to Phase 6.",
        "If `gemini-review` MCP is unavailable or Gemini CLI login is missing, record the external-review blocker.",
    )
    text = text.replace("re-submit for another round via `send_input`", "re-submit for another round via `mcp__gemini_review__review_reply_start` plus `mcp__gemini_review__review_status`")
    text = re.sub(r"^-\s+\*{0,2}REVIEWER_MODEL.*$", REVIEWER_LINE, text, flags=re.MULTILINE)
    text = re.sub(r"## Prerequisites\n\n(?:- .*\n)+", PREREQ_BLOCK + "\n\n", text, count=1)
    text = text.replace("Gemini CLI review Review", "Gemini Review")
    text = text.replace("Gemini reviewer Review", "Gemini Review")
    text = text.replace("Gemini reviewer reviewer", "Gemini reviewer")
    text = SPAWN_BLOCK_RE.sub(rewrite_spawn_block, text)
    text = SEND_BLOCK_RE.sub(rewrite_send_block, text)
    text = text.replace(
        "```\nreasoning_effort: xhigh\n```",
        "```\nmcp__gemini_review__review_start:\n  prompt: |\n    [Full novelty briefing + prior work list + specific novelty questions]\n```",
    )
    return append_async_notes(text)


def generate_one(skill_name: str) -> None:
    skill_path = SRC_ROOT / skill_name / "SKILL.md"
    content = skill_path.read_text(encoding="utf-8")
    match = FRONTMATTER_RE.match(content)
    if not match:
        raise ValueError(f"Missing frontmatter: {skill_path}")

    frontmatter = match.group(1)
    body = content[match.end():].lstrip("\n")
    output = f"---\n{rewrite_frontmatter(frontmatter)}\n---\n\n"
    output += OVERRIDE_NOTE + "\n\n"
    output += transform_body(body).rstrip() + "\n"

    target_dir = DEST_ROOT / skill_name
    if target_dir.exists():
        shutil.rmtree(target_dir)
    target_dir.mkdir(parents=True, exist_ok=True)
    (target_dir / "SKILL.md").write_text(output, encoding="utf-8")


def main() -> None:
    DEST_ROOT.mkdir(parents=True, exist_ok=True)
    for skill_name in TARGET_SKILLS:
        generate_one(skill_name)


if __name__ == "__main__":
    main()
