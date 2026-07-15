You are working on a minimal Python implementation of CuTe layout algebra.

The reference source for the math is Cris Cecka, "CuTe Layout Representation and
Algebra", arXiv:2603.02298. For this task, only implement the `composition`
operation for the starter `Layout` class. Do not implement unrelated CuTe
features.

## What to edit

Edit `/app/pycute/layout.py` and complete:

```python
def composition(layoutA, layoutB):
```

The rest of the file provides the required public API and helper functions:
`Layout`, `make_layout`, `size`, `cosize`, `flatten`, `prefix_product`,
`crd2idx`, and `coalesce`.

## Required behavior

CuTe layouts are represented as `shape:stride` and map a logical coordinate to a
linear index. Your implementation must return a layout `R` such that, for the
supported cases, `R(i) == layoutA(layoutB(i))` over `R`'s domain.

Support these cases:

- `layoutB is None`: return `layoutA` unchanged.
- `layoutB` is an integer: treat it as `Layout(layoutB)`.
- `layoutB` is a tuple: compose each mode of `layoutA` with the matching entry
  of `layoutB`; `None` entries are no-ops for that mode.
- `layoutB.shape` is hierarchical: compose `layoutA` with each mode of
  `layoutB` and combine the results with `make_layout`.
- stride-zero `layoutB`: return a stride-zero layout with `layoutB.shape`.
- general rank-1 `layoutB`: use coalesced modes of `layoutA` to compute the
  composed shape and stride.
- integer strides may be zero, positive, or negative in the supported
  pure-`Layout` cases.

Preserve the existing API, assertions, and string representations. Do not
hardcode verifier cases, read `/tests`, or write `/logs/verifier/reward.txt`.
The verifier includes cases mirrored from CUTLASS's CuTe composition unit tests,
limited to the pure Python `Layout` API provided here.

## Useful commands

```bash
python3 -m pytest /tests/test_outputs.py -rA
python3 - <<'PY'
from pycute import Layout, composition
A = Layout((4, 3), (2, 8))
B = Layout(3, 2)
print(composition(A, B))  # expected: 3:4
PY
```
