You are working on a custom HIP paged-attention kernel for AMD MI350
(ROCm/gfx950). The current kernel at `/app/pa.cpp` was written for head
dimension 128. Your task is to update it so it works correctly and efficiently
for **head dimension 256**.

## What to edit

Edit `/app/pa.cpp` in place. Keep the exported kernel names and signatures:

- `pa(...)`
- `pa_reduce(...)`

The verifier compiles `/app/pa.cpp` as a normal PyTorch HIP extension. Do not
depend on `pyhip`, generated Python JIT code, or a Python-side fallback.

## Required behavior

The verifier uses:

- `B = 1`
- `HQ = 32`
- `HK = 4`
- `S = 256`
- `BLOCK_SIZE = 1`
- bf16 query/key/value tensors
- NHD key/value cache layout `[num_blocks, block_size, HK, S]`

The paged-attention math is:

```text
scores = (Q @ K^T) * (1 / sqrt(S))
out    = softmax(scores) @ V
```

Your kernel may keep the existing two-stage structure: `pa` writes partition
outputs/max/sum, and `pa_reduce` combines partitions into the final output.

## Hints

The 128-dimensional version only writes and reduces one `bfloat16x2` vector per
lane. For `S = 256`, each lane must cover four bf16 elements in the final
write/reduce path, and the intermediate partition output must preserve both
halves of the 256-wide head dimension.

Check all places where the code assumes `S == 128`, especially:

- LDS output writeback from the four warps in `pa`
- the final write to `out_seg`
- `pa_reduce`, which combines `out_seg`, `max_out`, and `sum_out`

## How you are graded

The grader is pyhip-free and deterministic:

1. **Build/load**: `/app/pa.cpp` must compile as a PyTorch HIP extension.
2. **No pyhip dependency**: the submitted source must not import or include
   pyhip-generated code.
3. **Correctness**: fresh random inputs are compared against a Torch reference
   for head dimension 256.
4. **Performance**: your `pa + pa_reduce` path is benchmarked against aiter's
   `torch.ops.aiter.paged_attention_ragged` on the same tensors and must clear
   the configured performance floor.

Use the default visible GPU; it is already selected for the container.
