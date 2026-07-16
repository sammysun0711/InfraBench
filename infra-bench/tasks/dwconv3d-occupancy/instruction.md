You are optimizing a **register-bound** BF16 depthwise 3D convolution HIP kernel
on an AMD MI35X (CDNA4, gfx950) GPU. The kernel's occupancy is limited by its
high VGPR (vector register) usage — improve the occupancy and it runs faster.

## The kernel

`/app/kernels/conv_depthwise3d_hip.cpp` implements `conv_depthwise3d_hip`
(entry symbol, `__launch_bounds__(256, 1)`). Its hot loop **batches many
`ds_read` loads and then issues many `v_fmac` MACs** — so a large number of
loaded values are live at once, inflating VGPR usage and capping how many waves
can run per SIMD.

The host harness `/app/bench_conv3d.cpp` includes your kernel (via
`-DKERNEL_SGB=0`), times it, prints throughput, and checks correctness against a
CPU float32 reference. Build with:

```bash
cd /app && HIP_ARCH=gfx950 ./build.sh     # builds conv3d_depthwise_original
./conv3d_depthwise_original 50 10          # 50 timed iters, 10 warmup
```

Problem size: input NCHW `[1, 512, 61, 45, 80]` BF16, weights `[512,1,3,5,5]`,
padding `(0,2,2)`, stride/dilation 1.

## Goal

Edit **`/app/kernels/conv_depthwise3d_hip.cpp`** to **reduce VGPR pressure and
raise occupancy**, so the kernel runs at least **10% faster** (TFLOPS) while
still producing correct output. Keep the entry name `conv_depthwise3d_hip`, the
`__launch_bounds__(256, 1)`, and the kernel signature unchanged.

Instead of "read everything, then compute everything", you may consider
**interleave a few `ds_read` loads with the MACs that consume them**, which may 
lead to lower VGPR → higher occupancy.

## Profiling (available)

`rocprofv3` is installed. Use it to confirm the register/occupancy bottleneck and
verify your improvement, e.g.:

```bash
# Advanced Thread Trace:
rocprofv3 --att --kernel-include-regex '.*conv_depthwise3d_hip.*' \
    -d ./trace -- ./conv3d_depthwise_original 5 2 --no-check

# Hardware counters (add --output-format csv to get CSV instead of .db):
rocprofv3 -i counters.txt --output-format csv \
    --kernel-include-regex '.*conv_depthwise3d_hip.*' \
    -d ./cc -- ./conv3d_depthwise_original 5 2 --no-check
```

Useful counters include `SQ_WAVES`, `SQ_INSTS_VALU`, `GRBM_GUI_ACTIVE`,
`max_waves_per_simd`. You can also read the kernel's VGPR count from the compiled
ISA (`hipcc ... -S` and grep `.vgpr_count`).

## How you are graded

The grader does **not** trust any printed number. It builds + benchmarks both a
**frozen trusted copy of the original kernel** and **your edited kernel**, and
requires:
1. your kernel **builds** for gfx950 via the harness,
2. the benchmark's CPU float32 **correctness check passes** (atol=rtol=0.02),
3. your kernel's **VGPR count is meaningfully lower** than the original's
   (the occupancy proof — read from the compiled ISA), and
4. your kernel is **≥10% faster** (TFLOPS) than the original, measured by the
   grader itself back to back.

## Notes

- The GPU assigned to this container is pre-selected; use the default device.
- Do not read `/tests`, hardcode grader values, or write
  `/logs/verifier/reward.txt`.
- The optimization must come from the kernel schedule / register usage — a change
  that computes a wrong result fails the correctness gate.
