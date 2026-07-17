# InfraBench

20 real-world **AI-infrastructure engineering tasks** on **AMD MI35X (CDNA4 / gfx950)** GPUs, across five categories: model deployment, profiling analysis, kernel implementation, kernel tuning, and debug triage. Each task runs an agent in a Docker sandbox and is scored by a deterministic per-task verifier.

Built on [Terminal-Bench](https://github.com/harbor-framework/terminal-bench-2-1) / the `harbor` CLI.

## Requirements

- AMD ROCm GPUs (`/dev/kfd` + `/dev/dri`) and Docker
- `harbor` CLI and an LLM-gateway-authenticated agent
- Model weights at `/data/models` (mounted read-only into model-dependent tasks)

## Run

Set `INFRABENCH_GPU_COUNT` to your machine's GPU count (default 8), then:

```bash
# Whole suite (one job per task), staggered launches, N concurrent
INFRABENCH_GPU_COUNT=8 INFRA_PARALLEL=6 ./run.sh

# Single task
./run.sh -p tasks/hello-rocm

# Oracle (sanity-check a task/verifier — should score reward 1.0)
./run.sh -a oracle -p tasks/hello-rocm
```

Or run the published dataset directly:

```bash
export INFRABENCH_GPU_COUNT=8
harbor run -d infra-bench/infra-bench-v1@v1 -a claude-code -m <model> -n 6
```

**Concurrency:** two tasks need 2 GPUs (`qr-rmsnorm-fusion`, `sglang-mmmu-ipc-crash`); the GPU-pool allocator is non-blocking, so keep `INFRA_PARALLEL ≤ INFRABENCH_GPU_COUNT - 2`. All concurrent trials must run on a single host (pool arbitration is filesystem `flock`).

## Results & scoring

Output lands in `jobs/<timestamp>/`. `verifier/reward.txt` is the score (`1` = pass, `0` = fail); `run.sh` prints a `passed/total` summary. Use `harbor view jobs` to browse trajectories and `./analyze.sh jobs/<job>` to analyze failures.

## Layout

```
run.sh / analyze.sh   # run and analyze jobs (claude-code + gateway wrapper)
tasks/<name>/         # 20 task packages: instruction.md, environment/, solution/, tests/, task.toml
dataset.toml          # dataset manifest (infra-bench/infra-bench-v1)
jobs/<timestamp>/     # evaluation artifacts
```
