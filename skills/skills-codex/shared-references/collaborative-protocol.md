# Collaborative Protocol

Use this protocol when the executor and an external reviewer need multiple focused turns to diagnose a plateau or co-design a viable variant.

## Root-Cause Reanalysis

- Keep the discussion anchored to raw artifacts, not prior summaries alone.
- The reviewer owns independent diagnosis from files.
- The executor owns implementation evidence, feasibility constraints, and integration risks.
- Each turn must try to resolve one of:
  - current root cause
  - strongest alternative root cause
  - what prior rounds misread
  - minimum experiment or code change that can disambiguate the issue

## Collaborative Variant Design

- Start from one concrete reviewer proposal, not a vague brainstorm.
- The executor must answer feasibility, dependency, and evaluation impact.
- Narrow the proposal until both sides agree on:
  - exact mechanism
  - minimal code surface
  - expected win
  - failure mode to watch

## Turn Limits

- After 3 turns on the same issue, write a short convergence memo.
- After 6 turns total, stop open-ended discussion and request the minimum resolution action only.
- Do not launch a new experiment from a collaborative thread until the mechanism is concrete enough to implement and evaluate.
