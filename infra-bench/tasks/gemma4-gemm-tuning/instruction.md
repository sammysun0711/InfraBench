You are optimizing GPU GEMM (matrix-multiply) performance for the
`google/gemma-4-26B-A4B-it` model on an AMD MI350 GPU. The model runs in bf16,
and its linear layers dispatch to aiter's a16w16 (bf16) GEMM. The default kernel
selection is not optimal for this model's shapes — your job is to tune it.

## The shapes to tune

`/app/gemma4_untuned_gemm.csv` contains the real GEMM shapes this model uses
(captured from an 8K-input / 1K-output serving run), in aiter's untuned format:
`M,N,K,bias,dtype,outdtype,scaleAB,bpreshuffle`.

## What to do

Use aiter's a16w16 GEMM tuner to search kernel candidates for these shapes and
produce a **tuned config CSV** that runs faster than the default kernel
selection while preserving numerical correctness.

The tuner lives in the aiter source tree at `/sgl-workspace/aiter`:

```
cd /sgl-workspace/aiter
python3 csrc/gemm_a16w16/gemm_a16w16_tune.py \
  --input_file /app/gemma4_untuned_gemm.csv \
  --tune_file /app/gemma4_tuned_gemm.csv \
  --libtype triton,opus
```

`--libtype` selects which backends to search (choices: asm, opus, flydsl,
triton, skinny, torch). `triton,opus` tunes in a few minutes and is sufficient
to beat the default. NOTE: `flydsl` searches thousands of candidates per shape
and can take 4+ minutes PER shape — avoid it (and `--with-hipblaslt`, also very
slow) unless you have a large time budget; neither is required to succeed.

## Deliverable

Write your tuned config to **`/app/gemma4_tuned_gemm.csv`** (the aiter tuned-GEMM
format: `gfx,cu_num,M,N,K,...,libtype,solidx,splitK,us,kernelName,err_ratio,...`).

## Success criteria

The grader benchmarks, with aiter's production GEMM op, the total latency across
all shapes:
- **baseline** = the default kernel selection (no tuned config), and
- **your config** = `/app/gemma4_tuned_gemm.csv`.

To pass, the **aggregate (summed) latency across all shapes** with your config
must be at least **5% faster** than the baseline, and every shape must remain
numerically correct (err_ratio ≤ 0.05). Individual shapes need not all improve —
only the total must.

Notes:
- The GPU assigned to this container is pre-selected; use the default device.
- Your tuned CSV must contain valid kernels that actually run — the grader
  re-times them with the real op, so incorrect or bogus entries will fail.
