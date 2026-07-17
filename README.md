# InfraBench

**Benchmarking and Routing AI Agents for Production AI Infrastructure Engineering Tasks**

InfraBench is a benchmark of **20 real-world AI-infrastructure engineering tasks**
targeting **AMD MI35X (CDNA4 / gfx950)** GPUs. Each task drops an AI agent into a
Docker sandbox with a terminal, gives it a natural-language problem, and scores
the result with a **deterministic per-task verifier** — no LLM-as-judge. Tasks
span five categories: **model deployment, profiling analysis, kernel
implementation, kernel tuning, and debug triage**.

It is built on the [Harbor framework](https://github.com/harbor-framework/harbor), 
run with the `harbor` CLI, so any harbor-supported agent (claude-code, codex, opencode,
gemini, …) can be evaluated against the same tasks, driving any model reachable
through your LLM gateway (Claude, GPT, or open-source models such as GLM, Kimi,
DeepSeek).

---

## What a task looks like

Each task package under `infra-bench/tasks/<name>/` contains:

| File | Purpose |
|------|---------|
| `instruction.md` | the natural-language problem shown to the agent |
| `environment/Dockerfile` + `docker-compose.yaml` | the sandbox (base image, GPU passthrough, model mounts) |
| `solution/solve.sh` | the known-good **oracle** solution (used to prove the task is sound) |
| `tests/` | the **verifier** — launches/measures the agent's result and emits `reward.txt` (`1` = pass, `0` = fail) |
| `task.toml` | metadata: category, difficulty, timeouts, resources |

The verifier is the contract: it never trusts the agent's printed numbers. It
re-runs benchmarks, re-profiles, hashes baselines, and compiles the agent's code
against a frozen harness, so a task only passes when the work is actually correct.

### The 20 tasks

| Task | Category | Difficulty | GPUs |
|------|----------|-----------|------|
| `hello-rocm` | smoke-test | easy | 1 |
| `gemma4-sglang-serving-opt` | model-deployment | hard | 1 |
| `llm-fp8-quantize` | model-deployment | hard | 1 |
| `hotspot-analysis-torch-profiler` | profiling-analysis | medium | 1 |
| `mem-bandwidth-bench` | profiling-analysis | medium | 1 |
| `gluon-a8w8-mfma-att` | profiling-analysis | hard | 1 |
| `sglang-sync-stall` | profiling-analysis | hard | 1 |
| `gemma4-gemm-tuning` | kernel-tuning | hard | 1 |
| `triton-matmul-tuning` | kernel-tuning | medium | 1 |
| `dwconv3d-occupancy` | kernel-tuning | hard | 1 |
| `engram-triton-kernel` | kernel-implementation | hard | 1 |
| `flydsl-cdna4-preshuffle-gemm` | kernel-implementation | medium | 1 |
| `paged-attention-hd256` | kernel-implementation | hard | 1 |
| `gemm-fp8-ptpc-quant` | kernel-implementation | hard | 1 |
| `qr-rmsnorm-fusion` | kernel-implementation | hard | **2** |
| `llvm-simple-constant-propagation` | compiler-optimization | medium | 1 |
| `cute-layout-composition` | algorithm-implementation | medium | 1 |
| `pointnet2-hipify` | debug-triage | medium | 1 |
| `vllm-aiter-debug` | debug-triage | hard | 1 |
| `sglang-mmmu-ipc-crash` | debug-triage | hard | **2** |

---

## Prerequisites

- **AMD ROCm GPUs** (MI35X / gfx950) with `/dev/kfd` + `/dev/dri` accessible, and Docker.
- **`harbor` CLI** — installed as a `uv` tool at `~/.local/bin/harbor`.
- **LLM gateway credentials** in an env file (default `~/setup_env.sh`), exporting:
  - Anthropic path (claude-code): `AMD_LLM_GATEWAY_KEY`, `NTID`, `ANTHROPIC_BASE_URL`
  - OpenAI-compatible path (codex / opencode / open-source models):
    `LLM_GATEWAY_URL`, `LLM_GATEWAY_KEY`
- **Pre-downloaded model weights** at `/data/models` (mounted read-only into
  model-dependent tasks so agents don't re-download).

The agent runs *inside the container*, so it needs its own model credentials —
that is what the gateway env vars provide. (`harbor auth login` authenticates the
harbor CLI itself and is separate.)

---

## Dataset

The suite is published on the Harbor hub as **`infra-bench/infra-bench-v1`**.


## Getting started (Published dataset)
```bash
export INFRABENCH_GPU_COUNT=8    # your machine's GPU count
harbor run -d infra-bench/infra-bench-v1 -a claude-code -m <model> -n 6
```

## Getting started (Local dataset)

All commands run from `infra-bench/`. Each runner executes `tasks/` as a **local
dataset** (`harbor run -p tasks`), so results carry the dataset/agent/model/provider
metadata and use your live local task content (no publish needed). `run_claude_code.sh`
defaults to **`claude-code`** + **`claude-opus-4.8`** through the Anthropic gateway;
override with `MODEL=`. Filter to specific tasks with `-i <task>` (include) / `-x <task>` (exclude).

```bash
cd infra-bench

# Oracle sanity-check (applies the known-good solution; should score reward 1.0)
AGENT=oracle ./run_claude_code.sh -i hello-rocm

# One / a few tasks with a real agent
./run_claude_code.sh -i dwconv3d-occupancy
MODEL=claude-opus-4.6 ./run_claude_code.sh -i dwconv3d-occupancy -i hello-rocm

# Whole suite (one local-dataset job, N concurrent trials)
INFRABENCH_GPU_COUNT=8 INFRA_PARALLEL=6 ./run_claude_code.sh   # 8-GPU box
INFRABENCH_GPU_COUNT=4 INFRA_PARALLEL=3 ./run_claude_code.sh   # 4-GPU box

# Common passthrough flags (forwarded to harbor run)
./run_claude_code.sh -k 3                       # 3 attempts per task (pass@k)
./run_claude_code.sh --timeout-multiplier 1.5   # scale all task timeouts
```

**Set `INFRABENCH_GPU_COUNT` to your real GPU count** (default 8) — the allocator hands out card indices `0 … N-1`, so a wrong count claims non-existent cards. Keep **`INFRA_PARALLEL ≤ INFRABENCH_GPU_COUNT - 2`**: the allocator is non-blocking (a trial that can't claim its card(s) *fails*, not queues), and two tasks need 2 GPUs each (`qr-rmsnorm-fusion`, `sglang-mmmu-ipc-crash`). All concurrent trials must run on **one host** (pool arbitration is filesystem `flock`). The runners pass `--agent-setup-timeout-multiplier 3` to absorb concurrent agent-install contention.

Results land in `jobs/<job-name>/<task>__<id>/`; a `passed/total` summary prints at the end.

---

## Running different agents and models

`harbor` supports many agents (`-a`): `claude-code`, `codex`, `opencode`
(`acp:opencode`), `gemini-cli`, `kimi-cli`, `qwen-coder`, `aider`, and more. The
`-m` flag selects the model, resolved through whichever gateway the agent is
pointed at.

Three convenience wrappers handle gateway auth for you. Each runs `tasks/` as a
local dataset, takes `MODEL=` to override the model, `INFRA_PARALLEL=` for
concurrency, and forwards extra flags (`-i`/`-x`/`-k`/…) to `harbor run`.

| Runner | Agent | Gateway | Default model |
|--------|-------|---------|---------------|
| `run_claude_code.sh` | claude-code | Anthropic (`ANTHROPIC_BASE_URL`) | `claude-opus-4.8` |
| `run_codex.sh` | codex (`agents/amd_codex.py`) | AMD Unified (`/v1/responses`) | `gpt-5.5` |
| `run_open_code.sh` | opencode (custom `amd` provider) | AMD Unified | `gpt-5.5` |

`run_codex.sh` and `run_open_code.sh` inject the `Ocp-Apim-Subscription-Key`
header the AMD gateway requires (harbor's stock agents can't send it): codex via
a custom `agents/amd_codex.py` agent, opencode via an `--ak opencode_config`
provider block (its subkey is scrubbed from artifacts after each run).

```bash
# claude-code (Anthropic gateway)
MODEL=claude-opus-4.6 ./run_claude_code.sh -i hello-rocm

# Codex (AMD Unified gateway)
MODEL=gpt-5.5 ./run_codex.sh -i hello-rocm

# opencode (AMD Unified gateway) — pick the adapter for the model (see below)
MODEL=gpt-5.5 ./run_open_code.sh -i hello-rocm                                   # reasoning → responses API (default)
MODEL=gemini-3.1-pro-preview AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' ./run_open_code.sh -i hello-rocm   # chat model
```

**opencode model→adapter (`AMD_OPENCODE_NPM`).** The AMD gateway routes models to
different endpoints, so opencode's AI-SDK adapter must match:
- **Reasoning models** (`gpt-5.x`): served only via `/v1/responses` → `@ai-sdk/openai` (the default).
- **Chat models** (`gemini-*`, `DeepSeek-V4-Flash`, `Kimi-*`): served via `/v1/chat/completions` → `AMD_OPENCODE_NPM='@ai-sdk/openai-compatible'`.

The GPU-pool env vars (`INFRABENCH_GPU_POOL_HOST`, `INFRABENCH_GPU_COUNT`) and
the model mount (`INFRABENCH_MODELS_HOST`) that `run_claude_code.sh` exports are read by each
task's `docker-compose.yaml`; export them yourself when calling `harbor run`
directly for GPU tasks. **Set `INFRABENCH_GPU_COUNT` to your machine's real GPU
count** (default 8):

```bash
export INFRABENCH_GPU_POOL_HOST=/tmp/infrabench_gpu_pool
export INFRABENCH_GPU_COUNT=8        # <-- number of GPUs on THIS machine
export INFRABENCH_MODELS_HOST=/data/models
mkdir -p "$INFRABENCH_GPU_POOL_HOST" && chmod 777 "$INFRABENCH_GPU_POOL_HOST"
```

### GPU-pool environment variables (reference)

| Variable | Default | Meaning |
|----------|---------|---------|
| `INFRABENCH_GPU_COUNT` | `8` | **Number of GPUs on the host.** The allocator hands out card indices `0 … N-1`. Set this to your real count. |
| `INFRABENCH_GPU_POOL_HOST` | `/tmp/infrabench_gpu_pool` | Host dir holding the per-card `flock` lock files that arbitrate cards across concurrent trials. Must be on a **local filesystem shared by all trials on one host**. |
| `INFRABENCH_MODELS_HOST` | `/data/models` | Host dir with pre-downloaded model weights, mounted read-only into model-dependent tasks. |
| `INFRA_PARALLEL` | `4` | (`run_claude_code.sh` only) how many tasks run concurrently. Keep `≤ INFRABENCH_GPU_COUNT - 2`. |

> **Portability note:** the pool uses filesystem `flock`, which is **host-local**.
> All concurrently-running trials must be on **one machine** sharing one
> `INFRABENCH_GPU_POOL_HOST`. Multi-node distribution of a single run is not
> supported by this allocator.

---

## Job output & scoring

Each run creates `jobs/<timestamp>/<task>/` with:

- `result.json` — authoritative result: agent name/model, `verifier_result.rewards.reward`, phase timings.
- `verifier/reward.txt` — the score: `1` = pass, `0` = fail.
- `verifier/test-stdout.txt` — raw verifier output.
- `agent/<agent>.txt` + `agent/trajectory.json` — the agent's transcript / structured trajectory.
- `exception.txt` — present only when a trial errored (vs. just failing).

Aggregate a run by summing `reward.txt` across task dirs (`run_claude_code.sh` prints this
automatically). Distinguish three outcomes:
- **reward 1** — verifier passed.
- **reward 0** — verifier ran, task not solved.
- **exception** — trial errored before/around verification (e.g. an
  agent-auth failure shows up here, *not* as a task failure).

`harbor view jobs` opens a web UI to browse trajectories.

---

## Analyzing runs

`analyze.sh` wraps `harbor analyze` (through the same gateway) to inspect why
trials passed or failed:

```bash
./analyze.sh jobs/<timestamp>/                    # analyze a whole job
./analyze.sh jobs/<timestamp>/ --failing          # only failing trials
./analyze.sh jobs/<timestamp>/dwconv3d-occupancy  # one trial
```