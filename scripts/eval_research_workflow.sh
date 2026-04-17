#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="${1:-$ROOT_DIR}"
MANIFEST="${ROOT_DIR}/benchmarks/research_workflow/tasks.json"

python3 "${ROOT_DIR}/tools/research_workflow_eval.py"   --manifest "$MANIFEST"   --project-root "$PROJECT_ROOT"
