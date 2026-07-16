You are implementing a **fused GPU kernel** that combines a **communication op**
with a **memory-bound op** on 2× AMD MI35X (CDNA4, gfx950) GPUs, to avoid an
extra round-trip of the all-reduced tensor through HBM.

## Background

In tensor-parallel LLM serving, each transformer block does an **all-reduce** of
the residual stream across GPUs, then **adds the residual and applies RMSNorm**.
Done separately, the all-reduced tensor is written to HBM and read back for the
norm. Fusing the two — doing the add-residual + RMSNorm as an epilogue of the
all-reduce kernel, before the result ever leaves registers/LDS — removes that
round-trip.

aiter provides a custom two-shot IPC **quick all-reduce** and a **RMSNorm**, and a
fused entry point `qr_all_reduce_rmsnorm`. The all-reduce path and the RMSNorm
building blocks are complete, but the **fused epilogue is stubbed**.

## What to implement

Edit **`/app/aiter/csrc/include/quick_all_reduce.cuh`** — the
`AllReduceTwoshotRMSNorm::run(...)` device function (marked `TODO(agent)`). In a
single pass it must:

1. perform the two-shot quick all-reduce of `input` across ranks (the
   all-reduce-only version is `AllReduceTwoshot::run` in the same file — same
   communication pattern), then
2. add the per-rank `residual_inp` to the reduced value and write the sum to
   `residual_out` (the pre-normalization residual stream), then
3. compute RMSNorm over the `hidden_dim` axis on that sum and write to `output`:
   `output = x * rsqrt(mean(x^2 over hidden_dim) + eps) * weight`.

`N` = total elements, `hidden_dim` = normalization width (one row per token),
`weight` has `hidden_dim` elements, `T`/`CommT` are fp16 or bf16.

Keep the `run(...)` signature, the struct name, and the plain `qr_all_reduce`
path unchanged. Do **not** change the python API or the test.

## Building & testing

aiter JIT-compiles kernels and **caches the compiled `.so`** — after editing the
kernel you must force a rebuild:

```bash
export AITER_REBUILD=1
cd /app/aiter
HIP_VISIBLE_DEVICES=0,1 python3 -m pytest \
    op_tests/multigpu_tests/test_quick_all_reduce_rmsnorm.py -x
```

The test spawns 2 ranks and compares the fused output + residual_out against a
torch reference (all-reduce sum + residual + RMSNorm) for fp16 and bf16.

## How you are graded

The grader (2 GPUs, rebuilds your kernel with `AITER_REBUILD=1`):

1. **Accuracy** — the 2-GPU test passes: your fused `output` and `residual_out`
   match the torch reference for both fp16 and bf16 (rtol/atol 5e-3 fp16,
   4e-2 bf16).
2. **Performance** — at a large shape (65536×4096, bf16) the grader profiles your
   fused kernel and the unfused `qr_all_reduce` + `rmsnorm2d_fwd_with_add`
   baseline **under `rocprofv3 --kernel-trace`** (precise on-GPU kernel time),
   and requires the fused kernel to be **≥ 2% faster** than the summed unfused
   kernels — i.e. the fusion actually saves the RMSNorm HBM round-trip.

## Notes

- Two GPUs are pre-selected for this container (`HIP_VISIBLE_DEVICES` is set);
  use both.
- quick all-reduce requires `world_size ∈ {2,4,8}` and, for the fused RMSNorm,
  `hidden_dim × sizeof(T)` must divide the kernel tile size (power-of-2 hidden
  dims like 4096/8192 work).
- Do not read `/tests`, hardcode grader values, or write
  `/logs/verifier/reward.txt`.
