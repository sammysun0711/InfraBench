# InfraBench — Task Candidate Pool (Brainstorm)

Draft for discussion. A pool of **>20 candidates** across 5 categories; we pick
the final 20 (target 4/category) from these. Each must eventually pass the
Terminal-Bench bar: **specified / verifiable / solvable / not-hackable**
(agent can't win by reading the solution, editing tests, or faking output).

Legend:
- **Base image**: `pytorch` = `rocm/pytorch:rocm7.2.4_...` · `sglang` =
  `lmsysorg/sglang:v0.5.15-rocm720-mi35x`
- **GPUs**: how many the task needs from the pool.
- **Verifiable signal**: what the deterministic verifier measures itself.
- **Hack risk**: the main way an agent could cheat + how the verifier blocks it.
- **AMD**: 🔴 AMD-specific (tests ROCm/MI350-native skills, not portable from
  CUDA) · ⚪ generic GPU task (valuable but not AMD-differentiated).

> Design intent: InfraBench's value is the AMD/MI350-native content. Favor 🔴
> tasks; keep only the strongest ⚪ tasks. The new AMD-native section below
> (F) adds hipify, hipBLASLt, Composable Kernel, and FlyDSL candidates.

---

## A. Model Deployment
Serve / configure a model on MI350; correctness + a performance floor.

### A1. Serve gemma-4-26B-A4B-it with sglang, beat baseline throughput ✅ BUILT+VALIDATED
- Package: `infra-bench/tasks/gemma4-sglang-serving-opt/` · Image:
  `lmsysorg/sglang:v0.5.15-rocm720-mi35x` · **GPUs**: 1
- **Task** (open-ended): edit sglang source to improve serving throughput+TTFT
  while keeping accuracy. Agent must diagnose the triton MoE fallback itself.
- **Verifier**: measures pristine baseline (via `PYTHONPATH=/opt/sglang-pristine`)
  AND agent's edited sglang, both with the fixed launch/bench/gsm8k commands.
  Gates: TTFT >+10%, total throughput >+2%, GSM8K ≥0.955.
- **✅ Oracle validated end-to-end via harbor (2026-07-13, reward 1.0, 11m22s)**:
  | metric | baseline | agent(oracle) | gate | result |
  |---|---|---|---|---|
  | TTFT | 859.8 ms | 693.2 ms | >10% | −19.4% ✅ |
  | total throughput | 7200 tok/s | 7438 tok/s | >2% | +3.3% ✅ |
  | GSM8K | 0.98 | 0.98 | ≥0.955 | ✅ |
- **Bugs found+fixed during validation** (both important for future tasks):
  1. Pristine snapshot path: `cp -r src dst` copies *contents* when dst absent →
     `PYTHONPATH` silently fell back to the edited tree. Fix: `mkdir dst && cp -r
     src dst/sglang`; added a verifier guard that fails loudly if the baseline
     doesn't resolve to the snapshot.
  2. gsm8k runaway generation: default `max_tokens=None` → one degenerate
     non-stopping request generated ~187K tokens (30+ min) → verifier timeout.
     Fix: `sgl-eval ... --max-tokens 2048` (gsm8k needs few hundred; zero effect
     on correctness). Cut verifier from 40min-timeout to 11min.
- **Difficulty**: hard (🔴 AMD-native)
- **Agent run (claude-code/opus, 2026-07-13): reward 0** (19m38s,
  NonZeroAgentExitCodeError). Diagnosis was RIGHT — agent independently
  identified the MoE as the bottleneck (E=128/N=704, untuned triton MoE,
  prefill-heavy) — but chose a DIFFERENT fix: tune the triton MoE kernel for the
  exact shape, rather than pad→aiter. That path didn't activate (agent throughput
  7151 ≈ baseline 7192) and its run exited non-zero. Good difficulty signal:
  right area found unaided, but the specific 128-align/aiter fix is non-obvious
  enough a strong agent missed it. Task is solvable (oracle 1.0) but not easy.

- **⚠ SWEEP FINDING (2026-07-13): framework flags flat, BUT a real AMD-native
  optimization exists — enable aiter CK fused-MoE via padding.** Baseline 7177.
  - Framework levers dead-end: attention **locked to `triton`** (aiter/wave
    rejected by gemma-4; trtllm_mha is Blackwell-only); mem-fraction &
    chunked-prefill flat (±0.3%); torch.compile crashes (dynamo).
  - **ROOT CAUSE of the MoE fallback** (`srt/layers/quantization/unquant.py`
    `_aiter_ck_moe_supported`): aiter CK fused-MoE requires
    `intermediate_size_per_partition % 128 == 0`. Gemma-4's `moe_intermediate_size
    = 704` (=128×5.5, remainder 64) → falls back to the slower **triton MoE
    runner**. gpt-oss (already fast) doesn't hit this.
  - **THE OPTIMIZATION**: pad the MoE intermediate 704 → **768** (128×6) so
    `%128==0`, unlocking the aiter CK fused-MoE path on MI350.
    - **Numerically exact**: zero-padding gate/up output cols → activation at
      padded positions = `silu(0)*0 = 0` → contributes 0 through down_proj.
      Output unchanged, so GSM8K (0.985) preserved. Cost: ~9.1% extra MoE FLOPs,
      expected to be more than offset by the faster fused kernel.
  - **This makes A1 a genuine 🔴 AMD-native task**: agent must diagnose the
    triton fallback, understand the 128-alignment constraint, pad weights, and
    switch to aiter MoE — beating baseline throughput while accuracy holds.
  - **NO env var enables this** (checked full `environ.py` surface):
    - `SGLANG_MOE_PADDING` pads weight *storage* for mem-channel contention; in
      fp8.py it's an `elif` skipped when aiter is active — does NOT touch the
      `%128` gate.
    - `SGLANG_AITER_FUSE_RMSNORM_PAD` pads MoE *input hidden* (gpt-oss MXFP4 →
      256, post-attn-LN path, TP=1 only) — not the intermediate dim.
    - `SGLANG_USE_AITER_MOE_GU_ITLV` etc. = tile layout, irrelevant to the gate.
  - **sglang ALREADY has round-up-to-128 code** (`fused_moe_triton/layer.py:231`,
    `intermediate_size_per_partition = round_up(.., 128)`) but it fires ONLY for
    `use_flashinfer_trtllm_moe` (a CUDA/Blackwell path; flashinfer_trtllm and
    trtllm_mha both fail on MI350). The aiter path has no equivalent.
  - **So enabling aiter MoE for gemma-4 requires CODE, not config**: either
    (a) extend that round_up to the aiter branch, or (b) zero-pad the expert
    weights (w13→768 cols, w2→768 rows) at load time + set
    intermediate_size_per_partition=768. (a) is a ~2-line sglang patch.
  - **✅ PROTOTYPE PROVEN (2026-07-13)**: patched `process_weights_after_loading`
    in `srt/layers/quantization/unquant.py` to zero-pad MoE weights 704→768,
    update `intermediate_size_per_partition`, and re-call `create_moe_runner`
    (the `__init__`-time runner was built with unaligned 704, so rebuild is
    required). Gated behind env `SGLANG_AITER_MOE_PAD_INTERMEDIATE=1` +
    `SGLANG_USE_AITER=1`. Logs confirm aiter fused_moe now runs on gfx950 with
    dim 768. Backup at `/tmp/unquant.py.bak` in the a1base container.
  - **RESULT — aiter MoE (padded) vs triton baseline** (same bench):
    | metric | triton base | aiter padded | Δ |
    |---|---|---|---|
    | total throughput | 7177 | **7412 tok/s** | **+3.3%** |
    | mean TTFT | 861 ms | 689 ms | **−20%** |
    | mean TPOT | 9.20 | 9.05 ms | −1.6% |
    Faster despite +9% MoE FLOPs from padding. **GSM8K = 0.985 (identical to
    baseline)** — padding is numerically exact, confirmed. Optimization fully
    validated end-to-end.
  - **A1 is now a real 🔴 AMD-native task** (DECISIONS LOCKED):
    - **Deliverable = (a) CODE PATCH**: the agent edits sglang source
      (`srt/layers/quantization/unquant.py` or equivalent) to add the MoE
      padding path that enables aiter CK fused-MoE for gemma-4. Tests real infra
      code skills. Verifier applies/uses the agent's modified server.
    - **Pass criteria (ALL must hold)** vs. the triton baseline the verifier
      measures itself:
      - TTFT improvement **> 10%** (primary; strongest signal, base 861 ms)
      - Total token throughput improvement **> 2%** (base 7177 tok/s)
      - GSM8K accuracy **≥ 0.955** (sgl-eval; base 0.985, absorbs sampling noise)
    - Oracle achieves TTFT −20%, throughput +3.3%, acc 0.985 → passes cleanly.
  - **E2E build plan**: keep `a1base` container as the reference (patched
    unquant.py + baselines). Build the real task in a FRESH container via harbor
    (task #4), not by reusing a1base. Reference artifacts saved at
    `infra-bench/tasks/.a1_reference/` (oracle patch + both bench blocks).
  - **Verifier design (locked)**:
    - **Re-measures baseline every run** for fairness (robust to drift): launch
      STOCK sglang → bench → measure; then launch AGENT's modified sglang →
      bench → measure; compare. ~20 min/trial (2× server launch+bench+gsm8k).
    - Uses a FIXED canonical launch command for both, so the agent's optimization
      must be active by DEFAULT (not behind a private env var the verifier won't
      set). Oracle `solve.sh` makes the pad path default-on.
    - **Pristine-baseline mechanism (verified)**: sglang is an *editable* install
      (`.pth` finder → `/sgl-workspace/sglang/python`), so agent edits take
      effect live. Build time snapshots `cp -r .../python/sglang
      /opt/sglang-pristine/sglang`. Verifier launches BASELINE with
      `PYTHONPATH=/opt/sglang-pristine` (confirmed to override the editable
      install) and the AGENT run normally. Handles the open-ended instruction
      (agent may edit any file). NOTE: sglang tree is a git repo but has
      pre-existing uncommitted image build changes, so PYTHONPATH-snapshot is
      cleaner than git stash.
  - **Instruction (locked): OPEN-ENDED** — "improve serving throughput while
    keeping accuracy; analyze optimization potential incl. but not limited to
    attention backend, MoE, GEMM, kernel fusion." Agent must DIAGNOSE the triton
    MoE fallback itself (not told the answer).

### A2. Convert & load a HF checkpoint for inference
- **Image**: pytorch · **GPUs**: 1
- **Task**: given a HF model dir, write a script that loads it on GPU and runs
  inference; fix any dtype/device placement issues so it runs in bf16.
- **Verifiable**: verifier runs the script on held-out inputs, checks output
  matches a reference (allclose) and that peak VRAM < a cap (proves bf16, not
  fp32).
- **Hack risk**: precompute outputs on CPU → verifier changes inputs at test
  time and asserts GPU execution.
- **Difficulty**: easy–medium

### A3. Multi-GPU tensor-parallel serving
- **Image**: sglang · **GPUs**: 2
- **Task**: configure TP=2 serving for a model too "large" for the SLO on 1 GPU;
  get correct outputs across both GPUs.
- **Verifiable**: correctness on fresh prompts + verifier confirms 2 GPUs are
  actually engaged (both show utilization / memory during a load test).
- **Hack risk**: run on 1 GPU and claim TP=2 → verifier checks both claimed
  devices have model memory resident.
- **Difficulty**: medium–hard

### A4. Quantize a model and preserve accuracy
- **Image**: pytorch · **GPUs**: 1
- **Task**: apply weight quantization (e.g. int8/fp8 path available on ROCm) to
  a model; keep accuracy within tolerance on a small eval set while cutting VRAM.
- **Verifiable**: verifier measures accuracy delta < ε AND VRAM reduction >
  target vs. the fp16 baseline it computes itself.
- **Hack risk**: skip quantization, just report numbers → verifier measures both
  metrics from the produced artifact.
- **Difficulty**: hard

---

## B. Profiling Analysis
Given a workload, use ROCm profilers to find and report the truth.

### B1. Identify the top kernel hotspot (torch profiler) 🔴
- **Image**: `lmsysorg/sglang:v0.5.15-rocm720-mi35x` · **GPUs**: 1 · model
  gemma-4-26B-A4B-it · workload: 8K input / 5 output / concurrency 1
- **REFRAMED (2026-07-13)**: use **sglang's built-in torch profiler** (not
  rocprofv3). Reason: sglang spawns the scheduler in a subprocess, so
  `rocprofv3 -- python ...` only traces the parent and captures NO GPU kernels.
  sglang's `/start_profile`+`/stop_profile` endpoints (with
  `SGLANG_TORCH_PROFILER_DIR`) profile the scheduler where kernels run, and emit
  a chrome-trace `.trace.json.gz`. (The pure-rocprofv3 variant is deferred as
  **B1.1** for later.)
- **Task**: profile the fixed workload against a running sglang server and report
  the single most time-consuming GPU kernel (name + % of total GPU kernel time)
  to a JSON file, e.g. `/app/hotspot.json` `{"kernel": "...", "pct": NN.N}`.
- **Verifiable**: verifier launches the server (reuse A1's launch flow), runs the
  SAME fixed 8K/5 request under `/start_profile activities=[GPU]`, parses the
  trace, computes ground truth, and checks the agent's report matches.
- **✅ Ground truth measured** (saved `tasks/.b1_reference/ground_truth.json`):
  top = **`fused_moe_kernel` at 41.5%**, #2 `_fwd_kernel` 28.5%, #3+ are
  auto-named rocBLAS Tensile GEMMs (`Cijk_...`). Top two are stable clean names
  with a wide margin → robust hotspot ID.
- **Verifier matching (design)**: gate on **kernel name exact-match** (the top
  kernel `fused_moe_kernel` is stable) AND **pct within ±5 abs** of the
  verifier's own re-measured value. Do NOT hardcode the % (re-measure each run).
- **Hack risk**: guess a common name → verifier re-profiles; hotspot is
  workload/model-specific. Can't fake the % without a real trace.
- **✅ BUILT+VALIDATED (reward 1.0, 3m05s)**: package
  `infra-bench/tasks/hotspot-analysis-torch-profiler/`. Oracle reports
  `fused_moe_kernel 41.14%` vs verifier ground truth `41.53%` (0.4pt diff);
  name-match + pct±5 gates pass.
  - **Key fixes during build**:
    (1) single 5-tok `/generate` profile had ~10pt run-to-run variance in the
    pct → switched to `bench_serving --profile --num-prompt 4` (conc 1), which
    is reproducible to <1pt (40.97/41.49/41.42/41.14/41.53 across runs).
    (2) `python -m sglang.bench_serving` breaks if CWD contains a `sglang/` dir
    (imports local dir, shim can't find sglang.benchmark.serving) → force
    `cwd=/tmp` in both the verifier helper subprocess and solve.sh.
    (3) use `/opt/venv/bin/python` (has sglang), not system python3.
  - Full profiler helper is verifier-only (tests/profile_workload.py); agent must
    do its own profiling+trace parsing.
- **Difficulty**: medium

### B2. Diagnose a memory-bandwidth-bound op
- **Image**: pytorch · **GPUs**: 1
- **Task**: given a script, classify a specified op as compute- vs
  memory-bound and justify with a measured arithmetic-intensity / achieved-BW
  number written to a report.
- **Verifiable**: verifier checks the classification and that the reported
  achieved bandwidth is within tolerance of its own measurement.
- **Hack risk**: coin-flip the label → require the numeric evidence to match.
- **Difficulty**: medium

### B3. Find the host-device sync stall
- **Image**: pytorch · **GPUs**: 1
- **Task**: a script is slow due to needless `.item()`/`.cpu()` syncs in the
  loop; locate them and report line numbers + a fixed version that removes the
  stalls.
- **Verifiable**: verifier runs the fixed script, asserts same numerical output
  AND wall-time improvement > threshold (the stalls are gone).
- **Hack risk**: trivially rewrite unrelated code → speedup gate + output-parity
  gate must both pass.
- **Difficulty**: medium–hard

### B4. Attribute a multi-GPU comm bottleneck
- **Image**: pytorch · **GPUs**: 2
- **Task**: profile a 2-GPU workload dominated by RCCL all-reduce; report the
  collective's share of step time and which tensor sizes dominate.
- **Verifiable**: verifier's own trace confirms the reported collective + share
  within tolerance.
- **Hack risk**: generic "it's communication" answer → require specific op +
  quantified share matching ground truth.
- **Difficulty**: hard

---

## C. Kernel Implementation
Write a correct GPU kernel (HIP or Triton) matching a reference.

### C1. Fused softmax (Triton)
- **Image**: pytorch · **GPUs**: 1
- **Task**: implement a numerically-stable fused softmax Triton kernel with a
  given signature; must match `torch.softmax` on random inputs.
- **Verifiable**: allclose vs torch over many random shapes/dtypes incl. large
  rows (tests the online/stable path); verifier picks shapes at test time.
- **Hack risk**: call `torch.softmax` inside the "kernel" → verifier inspects
  that a Triton kernel is defined & launched (and forbids the torch op in the
  hot path via a wrapper/trace check).
- **Difficulty**: medium

### C2. Fused RMSNorm (Triton)
- **Image**: pytorch · **GPUs**: 1
- **Task**: implement RMSNorm forward as a Triton kernel matching a reference
  impl, incl. the weight scaling.
- **Verifiable**: allclose vs reference on fresh random inputs + a correctness
  edge case (zero variance row).
- **Hack risk**: same as C1 (delegate to torch) → trace/inspection gate.
- **Difficulty**: medium

### C3. Tiled GEMM (HIP)
- **Image**: pytorch · **GPUs**: 1
- **Task**: write a HIP tiled matmul kernel (shared-memory tiling) for given
  dims; compile with hipcc and match a reference within fp tolerance.
- **Verifiable**: compiles + numerically correct on fresh matrices; verifier
  provides its own test harness/dims.
- **Hack risk**: call rocBLAS → forbid library calls in the kernel; check the
  kernel source actually implements the compute (inspection + it must run
  standalone).
- **Difficulty**: hard

### C4. Flash-attention-style fused attention (Triton)
- **Image**: pytorch · **GPUs**: 1
- **Task**: implement a single-head fused attention kernel (QK^T, softmax, PV)
  matching a reference; must handle a causal mask.
- **Verifiable**: allclose vs reference (incl. causal) on fresh inputs; correct
  handling of a non-power-of-2 seq len.
- **Hack risk**: delegate to `torch.nn.functional.scaled_dot_product_attention`
  → inspection/trace gate on the hot path.
- **Difficulty**: hard

---

## D. Kernel Tuning
Start from a correct-but-slow kernel; beat a performance baseline while
staying correct.

### D1. Tune Triton block/num-warps for a given kernel
- **Image**: pytorch · **GPUs**: 1
- **Task**: given a working Triton kernel with default meta-params, tune
  BLOCK_SIZE / num_warps / num_stages to beat a baseline latency on target
  shapes.
- **Verifiable**: correctness unchanged (allclose) AND measured speedup ≥
  threshold vs. the baseline the verifier times itself, with warmup + repeats.
- **Hack risk**: fake the timer → verifier does its own timing; margin set
  above measurement noise (validated empirically).
- **Difficulty**: medium

### D2. Autotune GEMM tiling for a shape set
- **Image**: pytorch · **GPUs**: 1
- **Task**: pick tile sizes for a set of GEMM shapes to maximize throughput vs
  a naive baseline.
- **Verifiable**: correctness + aggregate TFLOP/s ≥ target across the shape set
  (verifier measures).
- **Hack risk**: overfit/hardcode one shape → verifier evaluates the full set
  incl. a held-out shape.
- **Difficulty**: hard

### D3. Reduce memory traffic via kernel fusion
- **Image**: pytorch · **GPUs**: 1
- **Task**: fuse an elementwise chain (e.g. bias+gelu+dropout-scale) that's
  currently multiple kernels into one; beat the multi-kernel baseline.
- **Verifiable**: output parity + latency improvement ≥ threshold + (optional)
  fewer kernel launches in the trace.
- **Hack risk**: change math to be faster-but-wrong → parity gate blocks it.
- **Difficulty**: medium–hard

### D4. Improve occupancy of a register-bound kernel
- **Image**: pytorch · **GPUs**: 1
- **Task**: a kernel spills registers / has low occupancy; refactor to raise
  occupancy and hit a speedup target.
- **Verifiable**: correctness + speedup ≥ threshold; verifier times it.
- **Hack risk**: unrelated micro-opt that doesn't generalize → fixed speedup
  gate with repeats.
- **Difficulty**: hard

---

## E. Debug Triage
Root-cause a failing / broken AI-infra scenario and fix it.

### E1. Fix an OOM in a training script
- **Image**: pytorch · **GPUs**: 1
- **Task**: a training script OOMs on MI350; diagnose (batch size / no grad
  checkpointing / leak) and make it complete N steps within the VRAM budget.
- **Verifiable**: script runs N steps to completion under a VRAM cap the
  verifier enforces, with loss decreasing (not a no-op).
- **Hack risk**: set batch=1 / disable the model → verifier requires real
  training signal (loss ↓) and a minimum effective throughput.
- **Difficulty**: medium

### E2. Fix a hanging multi-GPU (RCCL) job
- **Image**: pytorch · **GPUs**: 2
- **Task**: a 2-GPU DDP script hangs (mismatched collective / device misuse);
  find and fix the root cause so it completes.
- **Verifiable**: job completes within a timeout and produces correct synced
  results across ranks.
- **Hack risk**: drop to 1 GPU → verifier requires both ranks participate and
  results are actually all-reduced.
- **Difficulty**: hard

### E3. Fix a non-deterministic / NaN-producing kernel path
- **Image**: pytorch · **GPUs**: 1
- **Task**: a model emits NaNs after a few steps (bad init / overflow in a
  custom op / missing eps); locate and fix.
- **Verifiable**: N steps produce finite, reproducible outputs matching a
  reference tolerance.
- **Hack risk**: clamp/zero outputs to hide NaNs → verifier checks against a
  correct reference, not just finiteness.
- **Difficulty**: medium–hard

### E4. Resolve a ROCm environment/build failure
- **Image**: pytorch · **GPUs**: 1
- **Task**: a provided custom-op build (hipcc / setup.py) fails to compile or
  import on this ROCm version; fix the build so the op loads and runs on GPU.
- **Verifiable**: the extension builds, imports, and produces correct results
  on GPU on fresh inputs.
- **Hack risk**: stub the op in Python → verifier requires the compiled
  extension to be the code path and correct on GPU.
- **Difficulty**: medium

---

## F. AMD-Native Skills (🔴 high-priority — distributes across categories)
These are the tasks that make InfraBench AMD-specific rather than a generic GPU
benchmark. Each is tagged with the category it counts toward.

### F1. Hipify a CUDA kernel to HIP (→ Kernel Implementation) 🔴
- **Image**: pytorch · **GPUs**: 1
- **Task**: given a `.cu` CUDA kernel + host harness, port it to HIP so it
  compiles with hipcc and runs on MI350 (use `hipify-perl`/`hipify-clang` then
  fix the residue: warp size 64, unsupported intrinsics, `__shfl` semantics).
- **Verifiable**: HIP binary compiles, runs on GPU, and matches the CUDA
  reference output (verifier has the reference results) on fresh inputs.
- **Hack risk**: reimplement in torch / skip the kernel → verifier requires the
  compiled HIP kernel to be the code path; forbids torch fallback.
- **Note**: warp-size-64 correctness (a classic CUDA→HIP porting bug) is a
  great non-hackable signal — a naive hipify that assumes 32 fails.
- **Difficulty**: medium–hard

### F2. Tune a GEMM with hipBLASLt (→ Kernel Tuning) 🔴
- **Image**: pytorch · **GPUs**: 1
- **Task**: for a given GEMM shape/dtype, use hipBLASLt's algorithm search
  (heuristic + `hipblaslt-bench` / the ext-op API) to select the best-performing
  algo and wire it into a provided harness; beat the default-algo baseline.
- **Verifiable**: numerically correct + measured TFLOP/s ≥ threshold above the
  default hipBLASLt call the verifier times itself.
- **Hack risk**: fake timer / hardcode a number → verifier does its own timing
  with warmup+repeats; margin validated empirically.
- **Difficulty**: hard

### F3. aiter a16w16 (bf16) GEMM tuning for gemma-4 (→ Kernel Tuning) 🔴
- **Image**: `lmsysorg/sglang:v0.5.15-rocm720-mi35x` · **GPUs**: 1
- **REFRAMED (2026-07-13)**: originally "CK a8w8"; gemma-4 is **bf16 (not fp8)**
  so it never runs a8w8 kernels. Switched to **a16w16 (bf16)** which is what
  gemma-4 actually uses. Ref: aiter `csrc/gemm_a16w16/`.
- **Shapes are REAL, captured from gemma-4**: launch server with
  `AITER_TUNE_GEMM=1`, run 8K-in/1K-out request → aiter appends the model's GEMM
  shapes to `aiter/configs/bf16_untuned_gemm.csv`. gemma-4 has **12 distinct
  (N,K) weight shapes**; full capture (383 rows over ~55 M values) saved at
  `tasks/.f3_reference/gemma4_captured_full.csv`.
- **Task**: run the aiter a16w16 tuner on a provided untuned CSV to produce a
  tuned CSV that beats the default kernel selection, preserving correctness.
  ```
  python3 csrc/gemm_a16w16/gemm_a16w16_tune.py \
    --input_file <untuned.csv> --tune_file <tuned.csv>
  ```
- **Scope decisions (LOCKED)**:
  - **36-shape medium set** (12 weight shapes × M∈{1,128,8192}); untuned CSV
    saved at `tasks/.f3_reference/medium36_untuned.csv`.
  - **Non-hipblaslt backends** (asm, opus, flydsl, triton, skinny, torch — 6
    real backends). hipblaslt DROPPED from required path: pathologically slow
    (36 shapes not done at 26 min; subprocess-retry + 2000+ sols/shape). Agent
    MAY use `--with-hipblaslt` optionally but it's not needed to pass.
  - **Verifier is benchmark-only** (does NOT re-tune): uses `run_config` to time
    the agent's tuned CSV vs. the default, via env `AITER_CONFIG_GEMM_BF16`.
- **Timing measured**: non-hipblaslt ≈ **80s/shape** (6 shapes = 479s). So
  36-shape tune ≈ 30-45 min (agent budget); verifier benchmark-only ≈ 2-3 min.
- **Verifier mechanism (verified)**: production `gemm_a16w16` op reads tuned
  config from `AITER_CONFIG_GEMM_BF16` (env override). Baseline = point it at an
  EMPTY csv → op logs "not found tuned config, will use default"; Agent = point
  it at the agent's tuned csv. `run_config` reports per-shape `e2e_us` + err_ratio
  (allclose). Gate: aggregate tuned latency faster than default by ≥ threshold
  AND all shapes err_ratio ≤ 0.05.
- **Hack risk**: fake CSV / copy defaults → verifier re-times with the real op;
  a bogus/degenerate config fails correctness (err_ratio) or shows no speedup.
- **✅ BUILT+VALIDATED on v0.5.15 (reward 1.0, 5m39s)**: package
  `infra-bench/tasks/gemma4-gemm-tuning/`. Baseline 191.1us → tuned 179.7us =
  **5.9% aggregate speedup**, 11/11 shapes correct.
  - **Final scoped config** (after killing an impractical 33-shape/all-backend
    run that ran >50min): **11 shapes** (distinct gemma-4 weight shapes at M=128)
    × **`--libtype triton,opus`**. flydsl DROPPED — it searches 2000-4700
    candidates/shape (4+ min/shape); triton,opus ≈ 37s/shape.
  - **Two bugs found+fixed during validation**:
    1. Naive tuner picks regressive kernels (its internal timing disagrees with
       the production op) → 2/11 shapes slower → aggregate only 0.7%. Fix: oracle
       uses `--compare --update_improved --min_improvement_pct 3`, keeping only
       genuine winners (11 tuned entries → 5 kept; rest fall back to default).
    2. Verifier's `run_config` config-mode only benched the tuned CSV's shapes
       (5), not all 11 → unfair vs 11-shape baseline. Fix: rewrote `bench_gemm.py`
       to loop ALL shapes with the production op, tuned-vs-default selected purely
       via `AITER_CONFIG_GEMM_BF16`.
  - **Gate: ≥3%** aggregate speedup (measured 5.1-5.9% reproducibly; 3% gives
    margin vs timing noise) + all shapes err_ratio ≤ 0.05.
- **Difficulty**: hard

### F4. FlyDSL kernel implementation (→ Kernel Implementation) 🔴
- **Image**: pytorch (+ FlyDSL toolchain baked in) · **GPUs**: 1
- **Task**: implement a specified kernel (e.g. a reduction or elementwise-fused
  op) in FlyDSL; it must compile through the FlyDSL toolchain and match a
  reference.
- **Verifiable**: compiles via FlyDSL, runs on GPU, allclose vs reference on
  fresh inputs.
- **Hack risk**: bypass FlyDSL with a hand HIP kernel or torch → verifier
  requires the FlyDSL-generated artifact to be the code path.
- **Open Q**: confirm FlyDSL toolchain availability/version to bake into image.
- **Difficulty**: hard

### F5. aiter / fused-op integration for serving (→ Model Deployment) 🔴
- **Image**: sglang · **GPUs**: 1
- **Task**: enable/wire an AMD-optimized fused op (e.g. from `aiter`) into a
  serving path and show it produces correct outputs while improving latency.
- **Verifiable**: correctness on fresh prompts + p50 latency improvement ≥
  threshold vs. the non-fused baseline.
- **Hack risk**: claim without wiring → verifier checks the op is actually
  invoked (trace) and the latency gate holds.
- **Difficulty**: medium–hard

### F6. rocprofv3 / ATT trace analysis (→ Profiling Analysis) 🔴
- **Image**: pytorch · **GPUs**: 1
- **Task**: use rocprofv3 (or the Advanced Thread Trace) to extract a specific
  MI350 metric (e.g. VALU utilization, LDS bank conflicts, or MFMA usage) for a
  given kernel and report it.
- **Verifiable**: verifier runs its own rocprofv3 pass; reported metric within
  tolerance of ground truth.
- **Hack risk**: generic guess → workload-specific metric must match.
- **Difficulty**: medium–hard

### F7. Enable MFMA/matrix-core path for a kernel (→ Kernel Tuning) 🔴
- **Image**: pytorch · **GPUs**: 1
- **Task**: a kernel currently runs on VALU only; refactor to use the CDNA
  matrix cores (MFMA intrinsics / rocWMMA) for the matmul portion and hit a
  speedup target.
- **Verifiable**: correctness + speedup ≥ threshold + (optional) trace shows
  MFMA instructions issued.
- **Hack risk**: unrelated speedup → MFMA-usage + speedup gates.
- **Difficulty**: hard

---

## Selection view (pick final 20, target 4/category)

🔴 = AMD-specific, ⚪ = generic. Prefer 🔴.

| Category | 🔴 AMD-native | ⚪ generic | candidates |
|----------|--------------|-----------|------------|
| Deployment (A) | F5 | A1,A2,A3,A4 | 5 |
| Profiling (B) | F6 | B1,B2,B3,B4 | 5 |
| Kernel impl (C) | F1,F4 | C1,C2,C3,C4 | 6 |
| Kernel tuning (D) | F2,F3,F7 | D1,D2,D3,D4 | 7 |
| Debug triage (E) | (E4 is ROCm-ish) | E1,E2,E3,E4 | 4 |

Observations for discussion:
- **Kernel tuning is now deepest in AMD content** (hipBLASLt, CK, MFMA) — could
  justify weighting >4 there.
- **Debug triage is the thinnest on AMD-specificity** — want an AMD-native
  triage idea (e.g. debug a broken MFMA path, fix a warp-64 correctness bug, or
  resolve an rccl/rocm-version mismatch). Candidate: **E5 (new)** below.
- Deployment/Profiling each have 1 🔴; consider a 2nd AMD-native each.

### E5. Fix a CUDA-assumption bug on MI350 (→ Debug Triage) 🔴 (proposed)
- Port/run a kernel that silently produces wrong results because it assumes
  warpSize==32 (or hardcodes 32-lane shuffles); diagnose and fix for wavefront
  64. Verifier: output matches reference after fix. Strong AMD-native triage.

---

## Reference models (tiered)
Pick the cheapest model that still exercises the skill a task targets.

- **Full model: `gemma-4-26B-A4B-it`** (MoE, ~26B/4B active;
  `Gemma4ForConditionalGeneration`; bf16, multimodal — sliding+full attention).
  - **Chosen over gpt-oss-20b for A1**: gpt-oss is already near-optimal on this
    stack (aiter auto-tunes its MoE/GEMM at warmup; framework flags moved
    throughput <1%), leaving no fair headroom for an "improve throughput" task.
    gemma-4 falls back to the **triton MoE runner** (`aiter CK fused-MoE does not
    support intermediate_size_per_partition=704`) and its GEMMs hit
    `not found tuned config ... using default/torch solution` → real, tunable
    headroom for the oracle/agent.
  - Fits one MI350 (49 GB bf16 weights).
  - **Verified serving stack** (base image `lmsysorg/sglang:v0.5.15-rocm720-mi35x`):
    ```
    # serve (baseline uses --disable-radix-cache for an honest, cache-free number)
    python -m sglang.launch_server --model /models/gemma-4-26B-A4B-it \
      --disable-radix-cache
    # throughput benchmark — MUST use --dataset-name random for the --random-*
    # lengths to take effect (default is sharegpt, which IGNORES them and runs
    # short sequences).
    python3 -m sglang.bench_serving --backend sglang --dataset-name random \
      --num-prompt 128 --max-concurrency 8 --port 30000 \
      --random-input-len 8192 --random-output-len 1024 --random-range-ratio 1.0
    # accuracy signal — use sgl-eval (applies the chat template via /v1 chat API)
    pip install "git+https://github.com/sgl-project/sgl-eval"
    sgl-eval ping --base-url http://localhost:30000/v1        # sanity check
    sgl-eval run gsm8k --base-url http://localhost:30000/v1 --num-examples 200
    ```
    These give ready-made deterministic verifier signals: bench_serving →
    throughput/latency gate; sgl-eval gsm8k → accuracy gate.
    NOTE: use `sgl-eval`, NOT `sglang.test.few_shot_gsm8k` — the latter uses raw
    few-shot prompting without gemma-4's chat template and scored only 0.17;
    sgl-eval (chat API) scores 0.985 on the same server.
  - **Measured baseline** (GPU0, radix disabled, random 8192/1024, conc=8,
    128 prompts): total throughput **7177 tok/s** (input 6379, output 797 tok/s),
    req 0.78/s, mean TTFT 861 ms, mean TPOT 9.20 ms, duration 164 s. Raw block
    saved at `infra-bench/tasks/.a1_baseline_random.txt`.
  - gpt-oss-20b reference (kept as cheap/alt serving model): baseline 7679 tok/s
    total; near-optimal out of the box, so not used for the throughput task.
  - **gemma-4 baseline GSM8K accuracy: 0.985** (sgl-eval, 200 examples,
    single-shot greedy, chat API). Real quality bar + strong anti-hack anchor —
    98.5% is impossible without the model actually serving correctly.
    (The raw `sglang.test.few_shot_gsm8k` harness gave a misleading 0.17 — no
    chat template. Always use sgl-eval.)
  - **Accuracy gate rule**: `acc >= baseline_acc - ε` with ε ≥ ~0.03 to absorb
    sampling noise; the throughput gate is the real objective.
  - Use for tasks that need a *real, representative* model: end-to-end serving
    & latency SLO (A1, A3, F5), quantization/accuracy (A4), MoE-kernel profiling
    (B), MoE/attention-path triage (E).
- **Cheap verifier model: `Qwen/Qwen3.5-0.8B`** (smallest, dense).
  - Use for model-dependent tasks that only need *a real model to load/run*, not
    a large one: checkpoint load/dtype (A2), quick correctness-only serving,
    sanity of a deployment path. Keeps trials fast and VRAM tiny.
- **Synthetic tensors: no model at all.**
  - Pure kernel dev/tuning tasks (C1–C4, D1–D4, F1–F4, F6, F7) operate on
    verifier-generated random tensors vs. a reference — no checkpoint needed.
- **Models are pre-downloaded on the host** at `/data/models`, mounted
  **read-only** into every trial container so agents reuse them (no re-download):
  - `-v /data/models:/models:ro` → paths `/models/gpt-oss-20b` (50 GB on disk,
    `GptOssForCausalLM`; MoE 32 experts/4-per-tok, 24 layers, mxfp4) and
    `/models/Qwen3.5-0.8B` (1.7 GB, `Qwen3_5ForConditionalGeneration`).
  - RO mount verified (writes blocked); wire it via the task
    `docker-compose.yaml` `volumes:` (like the GPU-pool mount).
- **Serving image**: use `lmsysorg/sglang:v0.5.15-rocm720-mi35x` for
  gpt-oss-20b serving tasks (verified). The `lmsysorg/sglang:v0.5.15-...` image
  is the fallback/general sglang base; confirm per-task which one loads the arch.

## Cross-cutting design notes
- **Perf-gate margins** (categories A, D, parts of B/E): set thresholds well
  above measurement noise; verifier warms up + repeats; validate the margin
  empirically before shipping each task.
- **GPU exclusivity for perf tasks**: run perf-sensitive trials effectively
  alone on their claimed GPU (pool already pins 1 card/trial; consider `-n`
  lower for the perf subset).
- **Anti-hack pattern**: verifier always *measures ground truth itself* on
  *fresh* inputs and asserts real GPU execution (process/memory/trace), never
  trusting the agent's reported numbers.
- **Multi-GPU tasks** (A3, B4, E2) need the pool to claim 2 cards — extend the
  allocator to grab a pair.

## For discussion
1. **Final selection**: pick 20 from the ~28 pool. Keep 4/category, or weight
   toward kernel tuning where the AMD-native depth is (hipBLASLt/CK/MFMA)?
2. **AMD-native coverage**: Deployment & Profiling have only 1 🔴 each — add a
   2nd AMD-specific task to each? Adopt E5 for triage?
3. **Toolchain availability**: confirm what's installable/bakeable per image —
   hipBLASLt (present in ROCm), Composable Kernel, FlyDSL (F4), aiter (F5),
   rocprofv3/ATT (F6), rocWMMA (F7). Any not available blocks that task.
4. Too easy / too hard / too flaky to build?
5. Models decided (tiered): full = `/models/gpt-oss-20b` (MoE, mxfp4; serving
   verified on `lmsysorg/sglang:v0.5.15-rocm720-mi35x`), cheap verifier =
   `/models/Qwen3.5-0.8B`, pure-kernel tasks = synthetic tensors. Both mounted
   RO from `/data/models`. Serving signals ready: bench_serving + few_shot_gsm8k.
6. Priority order for Phase 1 vertical slices (one per category).
