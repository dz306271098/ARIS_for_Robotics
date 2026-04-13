#!/usr/bin/env python3
"""Audit Codex mainline parity for ARIS.

Checks:
1. Every skills-codex skill has complete frontmatter for name/description/argument-hint/allowed-tools.
2. Mainline docs and tools do not reference CLAUDE.md or AGENTS.md.
3. Mainline skills do not keep legacy /codex:* review commands or stale codex-specific tool declarations.
4. Reviewer-aware skills that use spawn_agent/send_input are covered by the Claude overlay generator.
"""

from __future__ import annotations

import ast
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CODEX_SKILLS = ROOT / "skills" / "skills-codex"
GENERATOR = ROOT / "tools" / "generate_codex_claude_review_overrides.py"
CHECK_PATHS = [
    ROOT / "skills" / "skills-codex",
    ROOT / "skills" / "skills-codex-claude-review",
    ROOT / "README_CN.md",
    ROOT / "docs" / "CODEX_CLAUDE_REVIEW_GUIDE.md",
    ROOT / "docs" / "CODEX_CLAUDE_REVIEW_GUIDE_CN.md",
    ROOT / "tools" / "research_wiki.py",
]
REQUIRED_FRONTMATTER_FIELDS = ("name", "description", "argument-hint", "allowed-tools")
FORBIDDEN_PATTERNS = ("CLAUDE.md", "AGENTS.md")
LEGACY_MAINLINE_SKILL_PATTERNS = (
    "/codex:rescue",
    "/codex:adversarial-review",
    "Bash(codex*)",
    "Skill(codex:rescue)",
    "Skill(codex:adversarial-review)",
)


def parse_frontmatter(path: Path) -> dict[str, str]:
    text = path.read_text(encoding="utf-8")
    match = re.match(r"^---\n(.*?)\n---\n?", text, re.S)
    if not match:
        return {}
    frontmatter = {}
    for line in match.group(1).splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        frontmatter[key.strip()] = value.strip()
    return frontmatter


def load_overlay_targets() -> set[str]:
    text = GENERATOR.read_text(encoding="utf-8")
    match = re.search(r"TARGET_SKILLS = \[(.*?)\]", text, re.S)
    if not match:
        return set()
    return set(ast.literal_eval("[" + match.group(1) + "]"))


def iter_skill_files(root: Path):
    for path in sorted(root.iterdir()):
        skill = path / "SKILL.md"
        if path.is_dir() and skill.exists():
            yield skill


def main() -> int:
    problems: list[str] = []

    for skill in iter_skill_files(CODEX_SKILLS):
        frontmatter = parse_frontmatter(skill)
        missing = [field for field in REQUIRED_FRONTMATTER_FIELDS if field not in frontmatter]
        if missing:
            problems.append(f"{skill.relative_to(ROOT)} missing frontmatter fields: {', '.join(missing)}")

    for base in CHECK_PATHS:
        files = [base] if base.is_file() else list(base.rglob("*"))
        for path in files:
            if path.is_dir():
                continue
            try:
                text = path.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                continue
            for pattern in FORBIDDEN_PATTERNS:
                if pattern in text:
                    problems.append(f"{path.relative_to(ROOT)} contains forbidden mainline reference: {pattern}")

    for skill in iter_skill_files(CODEX_SKILLS):
        text = skill.read_text(encoding="utf-8")
        for pattern in LEGACY_MAINLINE_SKILL_PATTERNS:
            if pattern in text:
                problems.append(
                    f"{skill.relative_to(ROOT)} contains legacy mainline review pattern: {pattern}"
                )

    overlay_targets = load_overlay_targets()
    reviewer_aware = set()
    for skill in iter_skill_files(CODEX_SKILLS):
        text = skill.read_text(encoding="utf-8")
        if "spawn_agent:" in text or "send_input:" in text:
            reviewer_aware.add(skill.parent.name)

    missing_overlay = sorted(reviewer_aware - overlay_targets)
    if missing_overlay:
        problems.append(
            "Overlay generator missing reviewer-aware skills: " + ", ".join(missing_overlay)
        )

    if problems:
        print("Codex mainline parity check failed:\n")
        for item in problems:
            print(f"- {item}")
        return 1

    print("Codex mainline parity check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
