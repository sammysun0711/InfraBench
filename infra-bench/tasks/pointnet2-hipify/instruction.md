You are porting a set of custom CUDA GPU operators to run on an AMD MI350 GPU
(ROCm/HIP). The code is the `pointnet2_ops` extension from the PointNet++ project
— hand-written CUDA kernels (furthest-point-sampling, ball-query, grouping,
gathering, three-nearest-neighbor interpolation) plus their C++/PyTorch bindings.
It was written for NVIDIA CUDA and does not build on ROCm as-is.

## The code

`/app/pointnet2_ops_lib/` contains the extension:
- `setup.py` — the build config (a PyTorch CUDAExtension).
- `pointnet2_ops/_ext-src/src/*.cu`, `*.cpp` — the CUDA kernels and bindings.
- `pointnet2_ops/_ext-src/include/*.h` — headers.
- `pointnet2_ops/pointnet2_utils.py`, `pointnet2_modules.py` — the Python API and
  neural-network modules that call the ops.

## Your task

Make the extension **build and run correctly on this ROCm**, so
that:

1. Build `pointnet2_ops_lib` module sucessfully on ROCm.
2. Make sure the custom ops produce correct results on the GPU — both individually and
   when composed into a PointNet++ Set-Abstraction / Feature-Propagation network
   (forward and backward).


## How you are graded

The grader builds your fixed extension, then runs a fixed-seed test that:
- calls each custom op directly and checks the outputs against reference values
  captured from a correct build, and
- builds a PointNet++ SA+FP model, runs forward + backward on fixed-seed input,
  and checks the output tensor against the reference.

All comparisons use fixed seeds and are deterministic. You cannot pass by
stubbing or faking the ops — the results must numerically match a genuinely
working GPU port.

Notes:
- The GPU assigned to this container is pre-selected; use the default device.
- Do not change the kernels' math/algorithms — only what's needed to build and
  run correctly on ROCm.
