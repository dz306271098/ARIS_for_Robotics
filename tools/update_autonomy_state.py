#!/usr/bin/env python3
"""Update AUTONOMY_STATE.json in a consistent way."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from autonomy_lib import autonomy_state_path, load_state, normalize_bool, now_iso


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Update ARIS unattended runtime state.")
    parser.add_argument("--project-root", default=".", help="Project root containing AUTONOMY_STATE.json")
    parser.add_argument("--state", help="Override path to AUTONOMY_STATE.json")
    parser.add_argument("--workflow")
    parser.add_argument("--phase")
    parser.add_argument("--status")
    parser.add_argument("--next-skill")
    parser.add_argument("--next-args")
    parser.add_argument("--blocking-reason")
    parser.add_argument("--retry-count", type=int)
    parser.add_argument("--review-mode")
    parser.add_argument("--review-replay-required")
    parser.add_argument("--external-model-replay-required")
    parser.add_argument("--recovery-step")
    parser.add_argument("--note")
    parser.add_argument("--touch-heartbeat", action="store_true")
    parser.add_argument("--clear", action="store_true", help="Delete the state file and exit.")
    parser.add_argument("--show", action="store_true", help="Print the current state without modifying it.")
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    project_root = Path(args.project_root).resolve()
    state_path = Path(args.state).resolve() if args.state else autonomy_state_path(project_root)

    if args.clear:
        state_path.unlink(missing_ok=True)
        return 0

    state = load_state(state_path)
    if args.show:
        print(json.dumps(state, indent=2, ensure_ascii=False, sort_keys=True))
        return 0

    now = now_iso()
    state.setdefault("started_at", now)
    state.setdefault("external_model_replay_required", False)
    review_replay_required = None
    if args.review_replay_required is not None:
        review_replay_required = normalize_bool(args.review_replay_required)
    external_model_replay_required = None
    if args.external_model_replay_required is not None:
        external_model_replay_required = normalize_bool(args.external_model_replay_required)

    updates = {
        "workflow": args.workflow,
        "phase": args.phase,
        "status": args.status,
        "next_skill": args.next_skill,
        "next_args": args.next_args,
        "blocking_reason": args.blocking_reason,
        "retry_count": args.retry_count,
        "review_mode": args.review_mode,
        "review_replay_required": review_replay_required,
        "external_model_replay_required": external_model_replay_required,
        "recovery_step": args.recovery_step,
        "note": args.note,
    }
    for key, value in updates.items():
        if value is not None:
            state[key] = value

    if args.touch_heartbeat or not state.get("last_heartbeat"):
        state["last_heartbeat"] = now

    state["updated_at"] = now
    state_path.parent.mkdir(parents=True, exist_ok=True)
    state_path.write_text(json.dumps(state, indent=2, ensure_ascii=False, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(state, indent=2, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
