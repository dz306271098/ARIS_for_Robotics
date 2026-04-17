#!/usr/bin/env python3
"""Shared helpers for ARIS unattended-autonomy tooling."""

from __future__ import annotations

import json
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


DEFAULT_AUTONOMY_PROFILE = {
    "autonomy_mode": "interactive",
    "automation_scope": "core_mainline",
    "priority": "quality_stability",
    "allow_auto_cloud": False,
    "allow_auto_real_robot": False,
    "require_watchdog": False,
    "require_wandb_for_unattended_training": False,
    "paper_illustration": "auto",
    "notifications": "off",
    "review_fallback_mode": "retry_then_local_critic",
    "resume_window_hours": 24,
    "max_reviewer_runtime_retries": 2,
    "max_auto_retries_per_stage": 3,
}

BOOL_KEYS = {
    "allow_auto_cloud",
    "allow_auto_real_robot",
    "require_watchdog",
    "require_wandb_for_unattended_training",
}
INT_KEYS = {"resume_window_hours", "max_reviewer_runtime_retries", "max_auto_retries_per_stage"}
RUNNING_INSTANCE_STATUSES = {"running", "active", "ready"}


def now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def normalize_bool(value: str | bool | None) -> bool:
    if isinstance(value, bool):
        return value
    text = str(value or "").strip().lower()
    return text in {"1", "true", "yes", "on"}


def parse_iso8601(value: str | None) -> datetime | None:
    if not value:
        return None
    text = str(value).strip()
    if not text:
        return None
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    try:
        parsed = datetime.fromisoformat(text)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def load_markdown_section_map(path: Path, heading: str) -> dict[str, str]:
    if not path.exists():
        return {}

    pattern = re.compile(
        rf"^##\s+{re.escape(heading)}\s*$\n(?P<body>.*?)(?=^##\s+|\Z)",
        re.MULTILINE | re.DOTALL,
    )
    text = path.read_text(encoding="utf-8")
    match = pattern.search(text)
    if not match:
        return {}

    data: dict[str, str] = {}
    for raw_line in match.group("body").splitlines():
        line = raw_line.strip()
        if not line or not line.startswith("- "):
            continue
        payload = line[2:]
        if ":" not in payload:
            continue
        key, value = payload.split(":", 1)
        data[key.strip()] = value.strip()
    return data


def load_autonomy_profile(project_root: Path) -> dict[str, object]:
    codex_path = project_root / "CODEX.md"
    profile = dict(DEFAULT_AUTONOMY_PROFILE)
    profile.update(load_markdown_section_map(codex_path, "Autonomy Profile"))

    for key in BOOL_KEYS:
        profile[key] = normalize_bool(profile.get(key))
    for key in INT_KEYS:
        try:
            profile[key] = int(profile.get(key, DEFAULT_AUTONOMY_PROFILE[key]))
        except (TypeError, ValueError):
            profile[key] = DEFAULT_AUTONOMY_PROFILE[key]

    return profile


def load_gpu_profile(project_root: Path) -> dict[str, str]:
    return load_markdown_section_map(project_root / "CODEX.md", "GPU Configuration")


def autonomy_state_path(project_root: Path) -> Path:
    return project_root / "AUTONOMY_STATE.json"


def load_state(path: Path) -> dict[str, object]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def load_vast_instances(project_root: Path) -> list[dict[str, Any]]:
    path = project_root / 'vast-instances.json'
    if not path.exists():
        return []
    data = json.loads(path.read_text(encoding='utf-8'))
    if isinstance(data, list):
        return [item for item in data if isinstance(item, dict)]
    return []


def find_running_vast_instance(project_root: Path) -> dict[str, Any] | None:
    for item in load_vast_instances(project_root):
        status = str(item.get('status', '')).strip().lower()
        if status in RUNNING_INSTANCE_STATUSES and item.get('instance_id'):
            return item
    return None


def allow_vast_reuse_without_provision(project_root: Path) -> bool:
    return find_running_vast_instance(project_root) is not None
