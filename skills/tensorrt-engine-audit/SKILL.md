---
name: tensorrt-engine-audit
description: Audit TensorRT engine builds — verify INT8/FP16 calibration accuracy drop ≤ declared threshold, layer fusion report, peak memory; emit TRT_ENGINE_AUDIT.json. Use when frameworks includes tensorrt.
argument-hint: [onnx-or-engine-path] [--precision fp16|int8]
allowed-tools: Bash(*), Read, Grep, Glob, Write, Edit
---

# TensorRT Engine Audit

When a paper claims "our TensorRT-optimized model runs 3× faster with only 0.2% accuracy drop", the claim has three parts — speed, precision, accuracy — any of which can be wrong. This skill builds (or re-parses) a TRT engine, runs calibration on a held-out set, and compares top-1 / top-5 / per-class metrics against the FP32 baseline.

## Activation Predicate

Fires when:
- `.aris/project.yaml` has `frameworks` including `tensorrt`
- An `.onnx` or `.trt` (engine) file is present
- Paper body contains TensorRT speedup or precision claims

## Workflow

### Step 1: Pre-flight

```
📋 Pre-flight:
   [ ] 1. ONNX or pre-built .trt engine identified
   [ ] 2. Calibration dataset (for INT8) declared — path + label format
   [ ] 3. FP32 reference accuracy recorded (baseline)
   [ ] 4. Target precision declared (fp16 / int8 / mixed)
   [ ] 5. TensorRT version + CUDA runtime captured
```

### Step 2: Build (or parse) the engine (host, remote, or container)

Pick the execution target via the same logic as `/cuda-build` Step 3.

```bash
$EXEC bash -c "
  # If .onnx supplied, build .trt
  if [[ -f model.onnx ]]; then
    /usr/src/tensorrt/bin/trtexec \\
      --onnx=model.onnx \\
      --saveEngine=model.trt \\
      --fp16 \\
      --timingCacheFile=timing.cache \\
      --exportLayerInfo=layer-info.json \\
      --exportProfile=profile.json \\
      --useCudaGraph
  fi
  # Inspect engine
  /usr/src/tensorrt/bin/trtexec --loadEngine=model.trt --dumpLayerInfo --verbose 2>&1 | tee engine-inspect.log
"
```

### Step 3: Accuracy audit (per-class, not just top-1)

Run the TRT engine and the FP32 reference on the same held-out set:

```bash
bash tools/container_run.sh -- bash -c "
  python3 scripts/eval_trt.py --engine model.trt --data data/val.bin --precision fp16 > trt-results.json
  python3 scripts/eval_trt.py --model model.pth --data data/val.bin --precision fp32 > fp32-results.json
"
```

### Step 4: Compute accuracy drops

```python
import json
trt = json.load(open("trt-results.json"))
fp32 = json.load(open("fp32-results.json"))

top1_drop = fp32["top1"] - trt["top1"]   # positive = TRT is worse
top5_drop = fp32["top5"] - trt["top5"]
per_class_max_drop = max(
    fp32["per_class"][c] - trt["per_class"][c] for c in fp32["per_class"]
)
```

### Step 5: Emit `TRT_ENGINE_AUDIT.json`

```json
{
  "audit_skill": "tensorrt-engine-audit",
  "verdict": "PASS|WARN|FAIL|NOT_APPLICABLE",
  "reason_code": "within_threshold | accuracy_drop_exceeds_claim | per_class_regression | engine_build_failed",
  "summary": "FP16 engine: top1 drop 0.12% (≤ 0.20% claim), top5 drop 0.03%, max per-class drop 0.4%.",
  "audited_input_hashes": {
    "model.onnx": "sha256:<hash>",
    "data/val.bin": "sha256:<hash>"
  },
  "trace_path": ".aris/traces/tensorrt-engine-audit/<run-id>/",
  "thread_id": "tensorrt-engine-audit-<timestamp>",
  "reviewer_model": "trtexec+python-eval",
  "reviewer_reasoning": "n/a",
  "generated_at": "2026-04-23T00:00:00Z",
  "details": {
    "tensorrt_version": "<from trtexec --version>",
    "cuda_runtime": "<from nvcc --version>",
    "gpu": "<model + sm_XX, as detected at runtime>",
    "precision": "fp16",
    "engine_build_time_s": 31.2,
    "engine_size_mb": 84,
    "peak_workspace_mb": 256,
    "layer_count_original": 312,
    "layer_count_fused": 147,
    "fusion_ratio_pct": 52.9,
    "latency_p50_ms": 1.2,
    "latency_p99_ms": 1.5,
    "top1_accuracy_trt": 0.7632,
    "top1_accuracy_fp32": 0.7644,
    "top1_drop_pct": 0.12,
    "top5_drop_pct": 0.03,
    "claimed_max_drop_pct": 0.20,
    "per_class_max_drop_pct": 0.4,
    "calibration_dataset_size": 1024
  }
}
```

Verdict:
- `PASS` — top1/top5 drop ≤ claim AND per-class max drop ≤ 2× claim
- `WARN` — top1/top5 drop ≤ claim BUT some per-class exceeds 2× claim (acknowledge in paper)
- `FAIL` — top1/top5 drop > claim
- `NOT_APPLICABLE` — no calibration data or FP32 baseline available (diagnostic only)

## Integration

- **Upstream**: model training pipeline (PyTorch / JAX) produces ONNX
- **Downstream**: `/paper-claim-audit` — accuracy claims cross-reference this audit
- **Audit gate**: `tools/verify_paper_audits.sh` requires this when `frameworks: [tensorrt]`

## Error Modes

| Failure | Fix |
|---|---|
| `trtexec: Unsupported ONNX op` | Use `--builtinPluginLibs` or rewrite op in ONNX graph |
| INT8 calibration OOM | Reduce calibration batch size; use `--maxWorkspace` flag |
| Engine works on build machine but fails elsewhere | TRT engines are GPU-arch specific — rebuild per target or use `--hardwareCompatibilityLevel` |

## See Also

- `skills/cuda-build/SKILL.md`
- `skills/cuda-correctness-audit/SKILL.md`
- `shared-references/build-system-contract.md`
- `tools/verify_paper_audits.sh`
