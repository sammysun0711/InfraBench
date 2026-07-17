# InfraBench
Github repository: [InfraBench](https://github.com/sammysun0711/InfraBench)

20 real-world **AI-infrastructure engineering tasks** on **AMD MI35X (CDNA4 / gfx950)** GPUs, across five categories: model deployment, profiling analysis, kernel implementation, kernel tuning, and debug triage. Each task runs an agent in a Docker sandbox and is scored by a deterministic per-task verifier.

Built on [Harbor framework](https://github.com/harbor-framework/harbor) via the `harbor` CLI.

## Requirements

- AMD ROCm GPUs (`/dev/kfd` + `/dev/dri`) and Docker
- `harbor` CLI and an LLM-gateway-authenticated agent
- Model weights at `/data/models` (mounted read-only into model-dependent tasks)

```bash
export INFRABENCH_GPU_COUNT=8
harbor run -d infra-bench/infra-bench-v1 -a claude-code -m <model> -n 6
```

**Concurrency:** two tasks need 2 GPUs (`qr-rmsnorm-fusion`, `sglang-mmmu-ipc-crash`); the GPU-pool allocator is non-blocking, so keep `INFRA_PARALLEL ≤ INFRABENCH_GPU_COUNT - 2`.
All concurrent trials must run on a single host (pool arbitration is filesystem `flock`).

## Results & scoring

Output lands in `jobs/<timestamp>/`. `verifier/reward.txt` is the score (`1` = pass, `0` = fail); 
Use `harbor view jobs` to browse trajectories and `harbor analyze jobs` to analyze failures.