You are porting a FlyDSL preshuffled fp16 GEMM kernel from a CDNA3-oriented
MFMA shape to CDNA4 on an AMD MI350 GPU. The machine can still run the old
CDNA3 kernel, so correctness alone is not enough: the source must use the CDNA4
MFMA atom explicitly.

## What to edit

Edit `/app/04-preshuffle_gemm.py`.

The starter file contains a working preshuffled GEMM implementation using:

```python
fx.make_mma_atom(fx.rocdl.MFMA(16, 16, 16, fx.Float16))
```

Port it to CDNA4 by using this exact MMA atom in the active tiled MMA
definition:

```python
fx.make_mma_atom(fx.rocdl.MFMA(16, 16, 32, fx.Float16))
```

You may adjust surrounding tiling or scheduling code if needed, but keep the
kernel in FlyDSL and keep the file runnable as a script.

Hint: changing only the MFMA atom is not sufficient. The CDNA4 fp16 atom has a
different K fragment shape, so update the tiled MMA K permutation and any
fragment slicing that still assumes the old nested CDNA3 K profile.

## Success criteria

The verifier checks that:

1. `/app/04-preshuffle_gemm.py` contains an active AST call to
   `fx.make_mma_atom(fx.rocdl.MFMA(16, 16, 32, fx.Float16))`.
2. The old active `MFMA(16, 16, 16, fx.Float16)` atom is no longer present.
3. Running the script on the assigned GPU reports `Result correct: True`
   against a PyTorch fp16 GEMM reference.
4. The candidate kernel is benchmarked against the frozen original CDNA3 kernel
   at the default `8192 x 8192 x 8192` shape on the same inputs; it must remain
   numerically correct and run at least 15% faster by median GPU-event time.

Notes:
- The GPU is pre-selected for the container; use the default device.
- The script honors `FLYDSL_TEST_M`, `FLYDSL_TEST_N`, and `FLYDSL_TEST_K` for
  smaller debug runs. Keep those environment overrides working if you refactor.
