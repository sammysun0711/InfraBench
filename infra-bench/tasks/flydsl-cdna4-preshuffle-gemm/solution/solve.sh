#!/bin/bash
set -euo pipefail

python - <<'PY'
from pathlib import Path

path = Path("/app/04-preshuffle_gemm.py")
text = path.read_text()
replacements = [
    (
        "fx.make_mma_atom(fx.rocdl.MFMA(16, 16, 16, fx.Float16))",
        "fx.make_mma_atom(fx.rocdl.MFMA(16, 16, 32, fx.Float16))",
    ),
    (
        "fx.make_tile(None, None, fx.make_layout((4, 4, 2), (1, 8, 4)))",
        "fx.make_tile(None, None, fx.make_layout((8, 4, 2), (1, 8, 32)))",
    ),
    (
        "mma_frag_A[None, None, (None, block_k_iter)],\n"
        "                mma_frag_B[None, None, (None, block_k_iter), read_stage],",
        "mma_frag_A[None, None, block_k_iter],\n"
        "                mma_frag_B[None, None, block_k_iter, read_stage],",
    ),
]
for old, new in replacements:
    if old not in text:
        raise SystemExit(f"expected pattern not found in {path}: {old}")
    text = text.replace(old, new, 1)
path.write_text(text)
PY
