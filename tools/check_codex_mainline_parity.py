#!/usr/bin/env python3
"""Audit Codex mainline parity for ARIS.

Checks:
1. Every skills-codex skill has complete frontmatter for name/description/argument-hint/allowed-tools.
2. The repo only keeps the expected Codex skill roots and retained reviewer branches.
3. Mainline docs plus retained reviewer branches do not reference CLAUDE.md / AGENTS.md / .claude-era paths.
4. Mainline skills do not keep legacy /codex:* review commands or stale codex-specific tool declarations.
5. Claude-review overlay skill descriptions round-trip cleanly from the Codex source descriptions.
6. Reviewer-aware skills that use spawn_agent/send_input are covered by the Claude overlay generator.
7. Core unattended-runtime artifacts and protocol markers are present.
"""

from __future__ import annotations

import ast
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CODEX_SKILLS = ROOT / "skills" / "skills-codex"
CLAUDE_OVERLAY_SKILLS = ROOT / "skills" / "skills-codex-claude-review"
GENERATOR = ROOT / "tools" / "generate_codex_claude_review_overrides.py"
CHECK_PATHS = [
    ROOT / "skills" / "skills-codex",
    ROOT / "skills" / "skills-codex-gemini-review",
    ROOT / "README.md",
    ROOT / "docs" / "CODEX_CLAUDE_REVIEW_GUIDE_CN.md",
    ROOT / "docs" / "INERTIAL_ODOMETRY_GUIDE_CN.md",
    ROOT / "skills" / "skills-codex" / "README_CN.md",
    ROOT / "skills" / "skills-codex-claude-review" / "README_CN.md",
    ROOT / "CONTRIBUTING.md",
    ROOT / "CONTRIBUTING_CN.md",
    ROOT / "scripts" / "install_codex_claude_mainline.sh",
    ROOT / "scripts" / "uninstall_codex_claude_mainline.sh",
    ROOT / "scripts" / "smoke_test_codex_claude_mainline.sh",
    ROOT / "scripts" / "check_unattended_mainline.sh",
    ROOT / "scripts" / "run_unattended_mainline.sh",
    ROOT / "mcp-servers" / "gemini-review",
    ROOT / "mcp-servers" / "minimax-chat",
    ROOT / "tools" / "research_wiki.py",
    ROOT / "tools" / "autonomy_supervisor.py",
    ROOT / "tools" / "update_autonomy_state.py",
    ROOT / "templates" / "CODEX_TEMPLATE.md",
    ROOT / "tools" / "research_workflow_eval.py",
    ROOT / "scripts" / "eval_research_workflow.sh",
]
REQUIRED_FRONTMATTER_FIELDS = ("name", "description", "argument-hint", "allowed-tools")
ALLOWED_TOP_LEVEL_SKILL_DIRS = {
    "skills-codex",
    "skills-codex-claude-review",
    "skills-codex-gemini-review",
}
REQUIRED_PRESENT_PATHS = [
    ROOT / "skills" / "skills-codex",
    ROOT / "skills" / "skills-codex-claude-review",
    ROOT / "skills" / "skills-codex-gemini-review",
    ROOT / "skills" / "skills-codex" / "shared-references" / "execution-test-gate.md",
    ROOT / "skills" / "skills-codex" / "shared-references" / "reviewer-resolution-protocol.md",
    ROOT / "skills" / "skills-codex" / "shared-references" / "unattended-runtime-protocol.md",
    ROOT / "skills" / "skills-codex" / "shared-references" / "collaborative-protocol.md",
    ROOT / "skills" / "skills-codex" / "shared-references" / "principle-extraction.md",
    ROOT / "skills" / "skills-codex" / "shared-references" / "innovation-lanes.md",
    ROOT / "skills" / "skills-codex" / "shared-references" / "literature-synthesis-protocol.md",
    ROOT / "skills" / "skills-codex" / "auto-review-loop-minimax",
    ROOT / "mcp-servers" / "claude-review",
    ROOT / "mcp-servers" / "gemini-review",
    ROOT / "mcp-servers" / "minimax-chat",
    ROOT / "scripts" / "check_unattended_mainline.sh",
    ROOT / "scripts" / "run_unattended_mainline.sh",
    ROOT / "tools" / "autonomy_supervisor.py",
    ROOT / "tools" / "update_autonomy_state.py",
    ROOT / "templates" / "CODEX_TEMPLATE.md",
    ROOT / "tools" / "research_workflow_eval.py",
    ROOT / "scripts" / "eval_research_workflow.sh",
]
FORBIDDEN_PRESENT_PATHS = [
    ROOT / "skills" / "shared-references",
    ROOT / "skills" / "skills-codex" / "auto-review-loop-llm",
    ROOT / "mcp-servers" / "llm-chat",
    ROOT / "templates" / "claude-hooks",
    ROOT / "tools" / "meta_opt" / "check_ready.sh",
    ROOT / "tools" / "meta_opt" / "log_event.sh",
]
FORBIDDEN_PATTERNS = (
    "CLAUDE.md",
    "AGENTS.md",
    "~/.claude",
    ".claude/",
    "templates/claude-hooks",
    "auto-review-loop-llm",
    "llm-chat",
)
LEGACY_MAINLINE_SKILL_PATTERNS = (
    "/codex:rescue",
    "/codex:adversarial-review",
    "Bash(codex*)",
    "Skill(codex:rescue)",
    "Skill(codex:adversarial-review)",
)
PROTOCOL_SKILL_MARKERS = {
    ROOT / "skills" / "skills-codex" / "experiment-bridge" / "SKILL.md": (
        "Mandatory Test Gate",
        "Reviewer Resolution Protocol",
        "Convergence Memo",
        "IMPLEMENTATION_TEST_GATE.md",
    ),
    ROOT / "skills" / "skills-codex" / "auto-review-loop" / "SKILL.md": (
        "Phase B.2: Reviewer Dispute Resolution",
        "Mandatory Test Gate",
        "Convergence Memo",
        "`accepted`, `narrowed`, `rebutted`, or `unresolved`",
    ),
    ROOT / "skills" / "skills-codex" / "deep-innovation-loop" / "SKILL.md": (
        "Mandatory Test Gate",
        "Reviewer Resolution Protocol",
        "Convergence Memo",
        "test-gate.md",
    ),
    ROOT / "skills" / "skills-codex" / "rebuttal" / "SKILL.md": (
        "Mandatory Test Gate",
        "Reviewer Resolution Protocol",
        "Convergence Memo",
    ),
}

AUTONOMY_SKILL_MARKERS = {
    ROOT / "skills" / "skills-codex" / "research-pipeline" / "SKILL.md": (
        "## Unattended Safe Mode",
        "AUTONOMY_STATE.json",
        "Autonomy Profile",
        "/result-to-claim",
        "/paper-writing",
    ),
    ROOT / "skills" / "skills-codex" / "idea-discovery" / "SKILL.md": (
        "## Unattended Safe Mode",
        "AUTONOMY_STATE.json",
        "review_replay_required",
    ),
    ROOT / "skills" / "skills-codex" / "research-refine-pipeline" / "SKILL.md": (
        "## Unattended Safe Mode",
        "AUTONOMY_STATE.json",
        "review_replay_required",
    ),
    ROOT / "skills" / "skills-codex" / "experiment-plan" / "SKILL.md": (
        "## Unattended Safe Mode",
        "AUTONOMY_STATE.json",
        "review_replay_required",
    ),
    ROOT / "skills" / "skills-codex" / "research-review" / "SKILL.md": (
        "## Unattended Safe Mode",
        "review_mode=local_fallback",
        "review_replay_required=true",
    ),
    ROOT / "skills" / "skills-codex" / "result-to-claim" / "SKILL.md": (
        "## Unattended Safe Mode",
        "AUTONOMY_STATE.json",
        "review_replay_required=true",
    ),
    ROOT / "skills" / "skills-codex" / "run-experiment" / "SKILL.md": (
        "## Unattended Safe Mode",
        "allow_auto_cloud",
        "require_watchdog",
        "AUTONOMY_STATE.json",
    ),
    ROOT / "skills" / "skills-codex" / "paper-plan" / "SKILL.md": (
        "## Unattended Safe Mode",
        "CLAIMS_FROM_RESULTS.md",
        "AUTONOMY_STATE.json",
    ),
    ROOT / "skills" / "skills-codex" / "paper-write" / "SKILL.md": (
        "## Unattended Safe Mode",
        "CLAIMS_FROM_RESULTS.md",
        "AUTONOMY_STATE.json",
    ),
    ROOT / "skills" / "skills-codex" / "paper-compile" / "SKILL.md": (
        "## Unattended Safe Mode",
        "AUTONOMY_STATE.json",
        "compile.log",
    ),
    ROOT / "skills" / "skills-codex" / "auto-paper-improvement-loop" / "SKILL.md": (
        "## Unattended Safe Mode",
        "review_mode=local_fallback",
        "review_replay_required=true",
    ),
    ROOT / "skills" / "skills-codex" / "paper-illustration" / "SKILL.md": (
        "## Unattended Safe Mode",
        "missing_illustration_backend",
        "AUTONOMY_STATE.json",
    ),
    ROOT / "skills" / "skills-codex" / "paper-writing" / "SKILL.md": (
        "## Unattended Safe Mode",
        "paper_illustration: auto",
        "AUTONOMY_STATE.json",
        "missing_illustration_backend",
    ),
}

RESEARCH_INTELLIGENCE_MARKERS = {
    ROOT / "skills" / "skills-codex" / "idea-creator" / "SKILL.md": (
        "IDEATION_LANES",
        "IDEA_PORTFOLIO.md",
        "safe`, `bold`, and `contrarian`",
    ),
    ROOT / "skills" / "skills-codex" / "research-refine" / "SKILL.md": (
        "ROUTE_PORTFOLIO.md",
        "Analogical / contrarian route",
        "shadow route",
    ),
    ROOT / "skills" / "skills-codex" / "experiment-plan" / "SKILL.md": (
        "branch-kill",
        "disconfirming",
        "PLAN_DECISIONS.md",
    ),
    ROOT / "skills" / "skills-codex" / "research-lit" / "SKILL.md": (
        "PRINCIPLE_BANK.md",
        "ANALOGY_CANDIDATES.md",
        "LITERATURE_OUTPUT_DIR",
    ),
    ROOT / "skills" / "skills-codex" / "research-wiki" / "SKILL.md": (
        "principle_pack.md",
        "analogy_pack.md",
        "failure_pack.md",
    ),
}

EXECUTION_PROFILE_MARKERS = {
    ROOT / "skills" / "skills-codex" / "research-pipeline" / "SKILL.md": (
        "EXECUTION_PROFILE = `CODEX.md -> ## Execution Profile`",
        "project_stack: cpp_algorithm",
        "project_stack: robotics_slam",
        "/dse-loop",
        "/system-profile",
    ),
    ROOT / "skills" / "skills-codex" / "experiment-plan" / "SKILL.md": (
        "EXECUTION_PROFILE = `CODEX.md -> ## Execution Profile`",
        "Compiled Project Block",
        "Robotics / SLAM Block",
        "benchmark matrix",
    ),
    ROOT / "skills" / "skills-codex" / "experiment-bridge" / "SKILL.md": (
        "EXECUTION_PROFILE = `CODEX.md -> ## Execution Profile`",
        "build/build_report.json",
        "results/benchmark_summary.json",
        "results/trajectory_summary.json",
        "profiles/nsys_summary.json",
    ),
    ROOT / "skills" / "skills-codex" / "run-experiment" / "SKILL.md": (
        "## Execution Profile Routing",
        "runtime_profile: cpu_cuda_mixed",
        "runtime_profile: slam_offline",
        "cmake configure -> build -> ctest -> benchmark",
    ),
    ROOT / "skills" / "skills-codex" / "monitor-experiment" / "SKILL.md": (
        "## Execution Profile Routing",
        "last_benchmark_summary.json",
        "last_robotics_summary.json",
        "profiles/nsys_summary.json",
    ),
    ROOT / "skills" / "skills-codex" / "result-to-claim" / "SKILL.md": (
        "EXECUTION_PROFILE = `CODEX.md -> ## Execution Profile`",
        "build/build_report.json",
        "trajectory_summary.json",
        "Correctness is a hard gate",
    ),
    ROOT / "scripts" / "check_unattended_mainline.sh": (
        "execution_profile",
        "cpp_algorithm",
        "robotics_slam",
        "nvcc",
    ),
    ROOT / "tools" / "autonomy_supervisor.py": (
        "## Execution Profile",
        "compiled execution path",
        "runtime_profile: cpu_cuda_mixed",
        "runtime_profile: slam_offline",
    ),
}

AUTONOMY_TEMPLATE_MARKERS = {
    ROOT / "templates" / "CODEX_TEMPLATE.md": (
        "## Execution Profile",
        "## CUDA Profile",
        "## Robotics Profile",
        "project_stack: python_ml",
        "review_fallback_mode: retry_then_local_critic",
        "max_reviewer_runtime_retries: 2",
        "run_unattended_mainline.sh",
        "innovation_mode: high_innovation",
        "topic_router: auto",
    ),
    ROOT / "README.md": (
        "## Execution Profile",
        "## CUDA Profile",
        "## Robotics Profile",
        "project_stack: cpp_algorithm",
        "project_stack: robotics_slam",
        "runtime_profile: cpu_benchmark",
        "runtime_profile: cpu_cuda_mixed",
        "runtime_profile: slam_offline",
        "review_fallback_mode: retry_then_local_critic",
        "max_reviewer_runtime_retries: 2",
        "paper-ready",
        "Research Intelligence Profile",
        "innovation_mode: high_innovation",
    ),
}

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


def extract_field(frontmatter_text: str, field: str) -> str:
    pattern = re.compile(rf"^{re.escape(field)}:\s*(.+)$", re.MULTILINE)
    match = pattern.search(frontmatter_text)
    if not match:
        return ""
    value = match.group(1).strip()
    if (value.startswith('"') and value.endswith('"')) or (value.startswith("'") and value.endswith("'")):
        try:
            value = ast.literal_eval(value)
        except (SyntaxError, ValueError):
            value = value[1:-1]
    return value


def frontmatter_text(path: Path) -> str:
    text = path.read_text(encoding="utf-8")
    match = re.match(r"^---\n(.*?)\n---\n?", text, re.S)
    return match.group(1) if match else ""


def normalize_overlay_description(text: str) -> str:
    text = text or "Claude-review override for a Codex-native ARIS skill."
    text = text.replace("GPT using a secondary Codex agent", "Claude via claude-review MCP")
    text = text.replace("using a secondary Codex agent", "using Claude Code via claude-review MCP")
    text = text.replace("via GPT-5.4 xhigh review", "via Claude review through claude-review MCP")
    return text


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

    skill_root_dirs = {path.name for path in ROOT.joinpath("skills").iterdir() if path.is_dir()}
    extra_roots = sorted(skill_root_dirs - ALLOWED_TOP_LEVEL_SKILL_DIRS)
    missing_roots = sorted(ALLOWED_TOP_LEVEL_SKILL_DIRS - skill_root_dirs)
    if extra_roots:
        problems.append("Unexpected top-level skill directories present: " + ", ".join(extra_roots))
    if missing_roots:
        problems.append("Expected top-level skill directories missing: " + ", ".join(missing_roots))

    for path in REQUIRED_PRESENT_PATHS:
        if not path.exists():
            problems.append(f"Required Codex-path artifact missing: {path.relative_to(ROOT)}")

    for path in FORBIDDEN_PRESENT_PATHS:
        if path.exists():
            problems.append(f"Forbidden legacy/sidecar path still present: {path.relative_to(ROOT)}")

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

    for overlay_skill in iter_skill_files(CLAUDE_OVERLAY_SKILLS):
        source_skill = CODEX_SKILLS / overlay_skill.parent.name / "SKILL.md"
        if not source_skill.exists():
            continue

        source_desc = normalize_overlay_description(
            extract_field(frontmatter_text(source_skill), "description")
        )
        overlay_desc = extract_field(frontmatter_text(overlay_skill), "description")
        if overlay_desc != source_desc:
            problems.append(
                f"{overlay_skill.relative_to(ROOT)} description mismatch: "
                f"expected normalized source description {source_desc!r}, got {overlay_desc!r}"
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

    for skill_path, markers in PROTOCOL_SKILL_MARKERS.items():
        text = skill_path.read_text(encoding="utf-8")
        missing_markers = [marker for marker in markers if marker not in text]
        if missing_markers:
            problems.append(
                f"{skill_path.relative_to(ROOT)} missing protocol markers: {', '.join(missing_markers)}"
            )

    for skill_path, markers in AUTONOMY_SKILL_MARKERS.items():
        text = skill_path.read_text(encoding="utf-8")
        missing_markers = [marker for marker in markers if marker not in text]
        if missing_markers:
            problems.append(
                f"{skill_path.relative_to(ROOT)} missing unattended markers: {', '.join(missing_markers)}"
            )

    for artifact_path, markers in AUTONOMY_TEMPLATE_MARKERS.items():
        text = artifact_path.read_text(encoding="utf-8")
        missing_markers = [marker for marker in markers if marker not in text]
        if missing_markers:
            problems.append(
                f"{artifact_path.relative_to(ROOT)} missing unattended markers: {', '.join(missing_markers)}"
            )

    for artifact_path, markers in RESEARCH_INTELLIGENCE_MARKERS.items():
        text = artifact_path.read_text(encoding="utf-8")
        missing_markers = [marker for marker in markers if marker not in text]
        if missing_markers:
            problems.append(
                f"{artifact_path.relative_to(ROOT)} missing research-intelligence markers: {', '.join(missing_markers)}"
            )

    for artifact_path, markers in EXECUTION_PROFILE_MARKERS.items():
        text = artifact_path.read_text(encoding="utf-8")
        missing_markers = [marker for marker in markers if marker not in text]
        if missing_markers:
            problems.append(
                f"{artifact_path.relative_to(ROOT)} missing execution-profile markers: {', '.join(missing_markers)}"
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
