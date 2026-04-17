#!/usr/bin/env python3
"""Evaluate whether a research-workflow run contains the new innovation artifacts."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


DIMENSIONS = {
    "novelty": ["NOVELTY_SURFACE.md", "closest prior", "novelty"],
    "literature_coverage": ["LITERATURE_MAP.md", "PRINCIPLE_BANK.md", "ANALOGY_CANDIDATES.md"],
    "principle_extraction_quality": ["PRINCIPLE_BANK.md", "Distilled principle", "preconditions"],
    "analogy_usefulness": ["ANALOGY_CANDIDATES.md", "analog", "cross-domain"],
    "plan_branch_quality": ["ROUTE_PORTFOLIO.md", "PLAN_DECISIONS.md", "branch-kill", "disconfirming"],
    "failure_response_creativity": ["failure_pack.md", "revive", "wrong assumption", "failure principle"],
}


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8") if path.exists() else ""


def score_dimension(project_root: Path, signals: list[str]) -> tuple[int, list[str]]:
    matched = []
    for signal in signals:
        if signal.endswith('.md'):
            for candidate in project_root.rglob(signal):
                if candidate.is_file():
                    matched.append(str(candidate.relative_to(project_root)))
                    break
        else:
            for candidate in project_root.rglob('*.md'):
                if signal.lower() in read(candidate).lower():
                    matched.append(signal)
                    break
    return len(matched), matched


def evaluate_run(project_root: Path, manifest_path: Path) -> dict:
    tasks = json.loads(read(manifest_path))
    task_results = []
    for task in tasks:
        missing = []
        for rel in task.get('required_artifacts', []):
            if not (project_root / rel).exists():
                missing.append(rel)
        task_results.append({
            'id': task['id'],
            'category': task['category'],
            'missing_artifacts': missing,
            'passed_artifacts': len(missing) == 0,
        })

    dimensions = {}
    for name, signals in DIMENSIONS.items():
        score, matched = score_dimension(project_root, signals)
        dimensions[name] = {
            'score': score,
            'max_score': len(signals),
            'matched': matched,
        }

    return {
        'project_root': str(project_root),
        'manifest': str(manifest_path),
        'tasks': task_results,
        'dimensions': dimensions,
    }


def compare_runs(baseline_path: Path, candidate_path: Path) -> dict:
    baseline = json.loads(read(baseline_path))
    candidate = json.loads(read(candidate_path))
    deltas = {}
    for name, current in candidate.get('dimensions', {}).items():
        previous = baseline.get('dimensions', {}).get(name, {}).get('score', 0)
        deltas[name] = current.get('score', 0) - previous
    return {
        'baseline': str(baseline_path),
        'candidate': str(candidate_path),
        'dimension_deltas': deltas,
    }


def main():
    parser = argparse.ArgumentParser(description='Evaluate research workflow artifacts')
    parser.add_argument('--manifest', default='benchmarks/research_workflow/tasks.json')
    parser.add_argument('--project-root')
    parser.add_argument('--output')
    parser.add_argument('--compare-baseline')
    parser.add_argument('--compare-candidate')
    args = parser.parse_args()

    if args.compare_baseline and args.compare_candidate:
        report = compare_runs(Path(args.compare_baseline), Path(args.compare_candidate))
    else:
        if not args.project_root:
            raise SystemExit('--project-root is required unless using compare mode')
        report = evaluate_run(Path(args.project_root), Path(args.manifest))

    payload = json.dumps(report, indent=2, ensure_ascii=False)
    if args.output:
        Path(args.output).write_text(payload + '\n', encoding='utf-8')
    print(payload)


if __name__ == '__main__':
    main()
