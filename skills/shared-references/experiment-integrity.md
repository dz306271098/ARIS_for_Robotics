# Experiment Integrity Protocol

## Core Principle

**The model that writes experiment code must NOT be the model that judges experiment integrity.** This is the same principle as reviewer-independence, applied to experiments.

## Prohibited Patterns

### 1. Fake Ground Truth
- Do NOT create synthetic "reference" from model outputs and compare against it
- Do NOT use baseline model outputs as ground truth
- Do NOT generate pseudo-GT that is structurally similar to predictions
- DO use dataset-provided ground truth
- DO use official evaluation scripts when available
- Proxy evaluation is allowed IF explicitly labeled as `synthetic_proxy`

### 2. Score Normalization Fraud
- Do NOT divide metrics by max/min of model's own output to get 0.99+
- Do NOT rescale scores to hide poor performance
- DO use standard normalization (e.g., min-max across ALL methods including baselines)
- DO report raw and normalized scores side by side

### 3. Phantom Results
- Do NOT claim results from files that don't exist
- Do NOT reference metrics from functions that are never called
- Do NOT report TRACKER status as DONE when it's still TODO
- DO ensure every claimed number traces to an actual output file

### 4. Insufficient Scope
- Do NOT report 2-scene pilot as "comprehensive evaluation"
- Do NOT use words like "robust", "extensive", "across settings" for tiny experiments
- DO honestly label scope: "pilot (N=2)", "preliminary", "limited evaluation"
- DO state exact scope: N scenes, N seeds, N configurations

## Evaluation Types (must be declared)

| Type | Label | What it means | Claim ceiling |
|------|-------|---------------|---------------|
| Real GT | `real_gt` | Dataset-provided ground truth | Full performance claims |
| Synthetic proxy | `synthetic_proxy` | Model-generated reference | "Proxy consistency" only |
| Self-supervised | `self_supervised_proxy` | No GT by design | Relative improvement only |
| Simulation | `simulation_only` | Simulated environment | "In simulation" qualifier |
| Human eval | `human_eval` | Human judges | Subject to inter-rater stats |

## Who Checks

The **reviewer model** (different family from executor) performs integrity checks via `/experiment-audit`. The executor collects file paths; the reviewer reads code and results directly.

**Never let the executor judge its own experiment integrity.**
