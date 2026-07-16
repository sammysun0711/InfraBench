You are triaging a **serving failure** on a newly built ROCm stack. This is a
**TheRock**-built ROCm 7.13 vLLM image for AMD MI35X (gfx950): ROCm is installed
as pip wheels (under `/opt/python/.../_rocm_sdk_*`), not the usual `/opt/rocm`
layout.

## Symptom

Launching Qwen3.5-0.8B with **AITER** enabled crashes during engine startup. The
provided launch script is `/app/launch_qwen3.5_0.8b.sh`:

```bash
export VLLM_ROCM_USE_AITER=1
python3 -m vllm.entrypoints.openai.api_server \
    --profiler-config '{"profiler": "torch", "torch_profiler_dir": "./vllm_profile_result"}' \
    --attention-config '{"backend": "ROCM_AITER_FA"}' \
    --model /models/Qwen3.5-0.8B --port 32000 --host 0.0.0.0 \
    --tensor-parallel-size 1 --trust-remote-code \
    --no-enable-prefix-caching --gpu-memory-utilization 0.8
```

The full failing engine-core log is at
`/app/vllm_server_qwen3.5-8b-aiter.log`. It ends in an engine-core crash while
AITER JIT-compiles an attention kernel.

## Goal

1. **Diagnose and fix** the root cause so the AITER server starts and serves.
2. Make the fix **persistent** in this container (the grader launches the server
   itself and expects your fix to already be in place).

## What "fixed" must achieve (how you are graded)

The grader launches the servers itself and does not trust any printed number. It
requires:

1. **root cause fixed** — the underlying version-probe crash is gone (the grader
   imports aiter's `get_hip_version()` and it must return a version, not raise);
2. **AITER server healthy** — the AITER=1 / `ROCM_AITER_FA` server reaches
   `/health`;
3. **CK FMHA prefill kernel present** — the grader drives the vLLM torch profiler
   (`POST /start_profile` → an 8k-input request → `POST /stop_profile`) and the
   captured trace must contain the CK FMHA prefill kernel
   (`ck_tile::FmhaFwdKernel`, via `aiter::mha_varlen_fwd`);
4. **faster TTFT** — AITER=1 median TTFT is at least 1.5× lower than the
   `VLLM_ROCM_USE_AITER=0` server's, at 8192-in / 1024-out; and
5. **≥2× total throughput** — AITER=1 total token throughput is at least twice
   the `VLLM_ROCM_USE_AITER=0` server's, same workload.

## Hints

- Reproduce first: run `/app/launch_qwen3.5_0.8b.sh` and read the traceback; then
  compare with `/app/vllm_server_qwen3.5-8b-aiter.log`.
- The crash is in AITER's HIP toolchain version probe. Check what
  `/opt/rocm/bin/hipconfig --version` does on this image vs. where ROCm actually
  lives (`echo $ROCM_PATH`).
- AITER kernels **JIT-compile on first use** — the first few requests are slow
  while kernels build. Warm the server before judging performance.
- Profiling: launch with the `--profiler-config` torch option (as the script
  does), then `curl -XPOST http://localhost:32000/start_profile`, send a request,
  `curl -XPOST http://localhost:32000/stop_profile`; the trace lands in the
  profiler dir. `rocprofv3` is also available.

## Notes

- The GPU assigned to this container is pre-selected; use the default device.
- The model is at `/models/Qwen3.5-0.8B`.
- Do not read `/tests`, hardcode grader values, or write
  `/logs/verifier/reward.txt`.
