# InfraBench Cross-Agent × Model Test Plan

Goal: run the full 20-task InfraBench suite across three agents, each driving
several models through the AMD LLM gateway or a compatible on-prem endpoint, and
collect a comparable agent × model scoreboard (reward, cost, latency) on the
Harbor hub.

All commands run from `infra-bench/`. Each runner executes `tasks/` as a **local
dataset** so every hub Jobs-table column fills (Datasets=`infra-bench`, Agents,
Providers, Models, Cost USD).

---

## Agent → model matrix

Each model family is driven by the agent that natively speaks its API:

| Agent | Runner | Provider (hub col) | Models to test |
|-------|--------|--------------------|----------------|
| **claude-code** | `run_claude_code.sh` | (blank — Anthropic gateway) | `claude-opus-4.6`, `claude-haiku-4.5`, `Claude-Sonnet-5`, `claude-opus-4.8` |
| **codex** | `run_codex.sh` | `openai` | `gpt-5.6-sol`, `gpt-5.6-luna`, `gpt-5.5`, `gpt-5.6-terra` |
| **opencode** | `run_open_code.sh` | `amd` | `DeepSeek-V4-Flash` (retest), `MiniMax-M2.7`, `Kimi-K2.6`, `Qwen3.6-35B-A3B`, `gemini-3.5-flash`, `Gemma-4-31B` |
| **opencode** | `run_open_code.sh` | `onprem` | `GLM-5.2-FP8` (Round 4, SGLang server at `http://10.145.64.81:30000/v1`), `MiniMax-M3` (Round 5, vLLM server at `http://10.145.64.81:30000/v1`), `Kimi-K2.7-Code` (Round 6, vLLM server at `http://10.145.64.81:30000/v1`), `Qwopus3.6-27B-Coder` (Round 6, local SGLang server at `http://127.0.0.1:9527/v1`), `Qwopus3.6-35B-A3B-Coder` (Round 6, local SGLang server at `http://127.0.0.1:9528/v1`), `Qwen3.5-397B-A17B-FP8` (Round 7, SGLang server at `http://10.145.64.81:30000/v1`), `MiMo-V2-Flash` (Round 8, SGLang server at `http://10.145.64.81:30000/v1`), `Qwen3.5-122B-A10B-FP8` (Round 9, local SGLang server at `http://10.145.64.87:30000/v1`), `MiMo-V2.5-Pro` (Round 10, SGLang server at `http://10.145.64.81:30000/v1`) |

All 14 gateway-backed planned models are available in the AMD LLM gateway
catalog (`/v1/models`). The Round 4 `GLM-5.2-FP8` run uses an on-prem SGLang
server because the AMD LLM gateway deployment is down. The Round 5 `MiniMax-M3`
and Round 6 `Kimi-K2.7-Code` runs use on-prem vLLM servers. The Round 7
`Qwen3.5-397B-A17B-FP8`, Round 8 `MiMo-V2-Flash`, and Round 10
`MiMo-V2.5-Pro` runs use on-prem SGLang servers on another MI350 machine. The
Round 9 `Qwen3.5-122B-A10B-FP8` run uses a local SGLang server pinned to GPUs 6
and 7. The Round 6
`Qwopus3.6-27B-Coder` and `Qwopus3.6-35B-A3B-Coder` runs use local SGLang
servers pinned to GPUs 6 and 7, so all InfraBench agent trials for those sweeps
must run with `INFRABENCH_GPU_COUNT=6` to keep GPUs 6/7 out of the task
allocator pool.

`Grok-4.3` is excluded from the active test plan. The dashboard shows the model
as operational, but the current AMD Unified endpoint and the runner's configured
gateway route reject `Grok-4.3` for both Chat Completions and Responses with
`Deployment of "Grok-4.3" ... is not found`.

> **opencode adapter rule (`AMD_OPENCODE_NPM`)** — the gateway routes models to
> different endpoints, so opencode's AI-SDK adapter must match the model:
> - **reasoning models** (`gpt-5.x`) → `@ai-sdk/openai` (Responses API) — the default
> - **chat models** (DeepSeek, MiniMax, Kimi, Qwen, Gemini, GLM) → `@ai-sdk/openai-compatible` (chat/completions)
>
> The models in *this* plan that go through opencode (DeepSeek-V4-Flash,
> MiniMax-M2.7, MiniMax-M3, Kimi-K2.6, Kimi-K2.7-Code,
> Qwen3.6-35B-A3B, Qwopus3.6-27B-Coder, Qwopus3.6-35B-A3B-Coder,
> Qwen3.5-397B-A17B-FP8, MiMo-V2-Flash, Qwen3.5-122B-A10B-FP8,
> MiMo-V2.5-Pro,
> gemini-3.5-flash, and Gemma-4-31B) are treated as chat models → always pass
> `AMD_OPENCODE_NPM='@ai-sdk/openai-compatible'`.

---

## Prerequisites (one-time)

- AMD ROCm GPUs (`/dev/kfd` + `/dev/dri`), Docker, `harbor` CLI.
- Gateway credentials in `~/setup_env.sh` (`AMD_LLM_GATEWAY_KEY`, `NTID`,
  `ANTHROPIC_BASE_URL`, `LLM_GATEWAY_*`). The runners source it automatically.
- The AMD gateway subscription key resolvable for codex/opencode — the runners
  read it from `~/.codex/config.toml` (`Ocp-Apim-Subscription-Key`) if
  `AMD_GATEWAY_SUBKEY` isn't already exported.
- Codex CLI + OpenCode installed (for their respective runners).
- `INFRABENCH_GPU_COUNT` set to the machine's real GPU count (default 8).

```bash
cd infra-bench
harbor auth status          # optional: needed only for publishing, not for runs
```

---

## Runner usage

Every runner shares the same interface:

| Env var | Meaning | Default |
|---------|---------|---------|
| `MODEL` | model id (see matrix) | claude-opus-4.8 / gpt-5.5 / gpt-5.5 |
| `INFRA_PARALLEL` | concurrent trials (`harbor -n`) | 4 |
| `INFRABENCH_GPU_COUNT` | GPUs on this host | 8 |
| `JOB_NAME` | hub job name (else timestamp) | `$(date +%F__%H-%M-%S)` |
| `AGENT=oracle` | (claude runner only) run the oracle | claude-code |
| `AMD_OPENCODE_NPM` | (opencode only) AI-SDK adapter | `@ai-sdk/openai` |
| `AMD_OPENCODE_PROVIDER` | (opencode only) provider id / Hub provider column | `amd` |
| `AMD_CODEX_BASE_URL` | codex/opencode base URL override | AMD Unified gateway |

Task selection (all runners): `-i <task>` include / `-x <task>` exclude
(repeatable); no flag = all 20. Extra flags (`-k 3`, `--timeout-multiplier 1.5`)
pass straight through to `harbor run`.

**GPU concurrency rule:** keep `INFRA_PARALLEL ≤ INFRABENCH_GPU_COUNT - 2`. Two
tasks need 2 GPUs each (`qr-rmsnorm-fusion`, `sglang-mmmu-ipc-crash`); the pool
allocator is non-blocking, so an over-subscribed trial *fails* rather than queues.
All trials must run on one host (pool arbitration is filesystem `flock`).

### Smoke test first (1 task per agent)

Before a full sweep, confirm each agent authenticates and passes `hello-rocm`:

```bash
# claude-code
MODEL=claude-opus-4.6 ./run_claude_code.sh -i hello-rocm

# claude-code round-2 addition
MODEL=claude-opus-4.8 ./run_claude_code.sh -i hello-rocm

# codex
MODEL=gpt-5.5 ./run_codex.sh -i hello-rocm

# codex round-3 addition
JOB_NAME=smoke-codex-gpt-5.6-terra MODEL=gpt-5.6-terra ./run_codex.sh -i hello-rocm

# opencode (chat model → openai-compatible adapter)
MODEL=DeepSeek-V4-Flash AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' ./run_open_code.sh -i hello-rocm

# opencode round-4 on-prem SGLang model
JOB_NAME=smoke-opencode-glm-5.2-fp8-onprem \
  MODEL=GLM-5.2-FP8 \
  AMD_OPENCODE_PROVIDER=onprem \
  AMD_CODEX_BASE_URL=http://10.145.64.81:30000/v1 \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' \
  ./run_open_code.sh -i hello-rocm

# opencode round-5 on-prem vLLM model; use the exact model id served by vLLM
JOB_NAME=smoke-opencode-minimax-m3-onprem-modelpath \
  MODEL=/models/MiniMax-M3 \
  AMD_OPENCODE_PROVIDER=onprem \
  AMD_CODEX_BASE_URL=http://10.145.64.81:30000/v1 \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' \
  ./run_open_code.sh -i hello-rocm

# opencode round-6 on-prem vLLM model; use the exact model id served by vLLM
JOB_NAME=smoke-opencode-kimi-k2.7-code-onprem-modelpath \
  MODEL=/models/Kimi-K2.7-Code \
  AMD_OPENCODE_PROVIDER=onprem \
  AMD_CODEX_BASE_URL=http://10.145.64.81:30000/v1 \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' \
  ./run_open_code.sh -i hello-rocm

# opencode round-6 local SGLang models; use the exact model ids served by SGLang
JOB_NAME=smoke-opencode-qwopus3.6-27b-coder-onprem-modelpath \
  MODEL=/models/Qwopus3.6-27B-Coder \
  AMD_OPENCODE_PROVIDER=onprem \
  AMD_CODEX_BASE_URL=http://10.145.64.87:9527/v1 \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' \
  INFRABENCH_GPU_COUNT=6 \
  ./run_open_code.sh -i hello-rocm

JOB_NAME=smoke-opencode-qwopus3.6-35b-a3b-coder-onprem-modelpath \
  MODEL=/models/Qwopus3.6-35B-A3B-Coder \
  AMD_OPENCODE_PROVIDER=onprem \
  AMD_CODEX_BASE_URL=http://10.145.64.87:9528/v1 \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' \
  INFRABENCH_GPU_COUNT=6 \
  ./run_open_code.sh -i hello-rocm

# opencode round-7 on-prem SGLang model; use the exact model id served by SGLang
JOB_NAME=smoke-opencode-qwen3.5-397b-a17b-fp8-onprem \
  MODEL=/models/Qwen3.5-397B-A17B-FP8 \
  AMD_OPENCODE_PROVIDER=onprem \
  AMD_CODEX_BASE_URL=http://10.145.64.81:30000/v1 \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' \
  INFRABENCH_GPU_COUNT=6 \
  ./run_open_code.sh -i hello-rocm

# opencode round-8 on-prem SGLang model; use the exact model id served by SGLang
JOB_NAME=smoke-opencode-mimo-v2-flash-onprem \
  MODEL=/models/MiMo-V2-Flash \
  AMD_OPENCODE_PROVIDER=onprem \
  AMD_CODEX_BASE_URL=http://10.145.64.81:30000/v1 \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' \
  INFRABENCH_GPU_COUNT=6 \
  ./run_open_code.sh -i hello-rocm

# opencode round-9 local on-prem SGLang model; use the exact model id served by SGLang
JOB_NAME=smoke-opencode-qwen3.5-122b-a10b-fp8-onprem \
  MODEL=/models/Qwen3.5-122B-A10B-FP8 \
  AMD_OPENCODE_PROVIDER=onprem \
  AMD_CODEX_BASE_URL=http://10.145.64.87:30000/v1 \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' \
  INFRABENCH_GPU_COUNT=6 \
  ./run_open_code.sh -i hello-rocm

# opencode round-10 on-prem SGLang model; use the exact model id served by SGLang
JOB_NAME=smoke-opencode-mimo-v2.5-pro-onprem \
  MODEL=/models/MiMo-V2.5-Pro \
  AMD_OPENCODE_PROVIDER=onprem \
  AMD_CODEX_BASE_URL=http://10.145.64.81:30000/v1 \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' \
  INFRABENCH_GPU_COUNT=6 \
  ./run_open_code.sh -i hello-rocm
```

For newly added opencode models and the DeepSeek retest, run a model-specific
`hello-rocm` smoke before the full sweep:

```bash
for MODEL in DeepSeek-V4-Flash Kimi-K2.6 Qwen3.6-35B-A3B gemini-3.5-flash Gemma-4-31B; do
  JOB_NAME="smoke-opencode-${MODEL,,}" \
  MODEL="$MODEL" AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' \
  ./run_open_code.sh -i hello-rocm
done
```

Each smoke should print `1/1 passed`. If an agent or model fails auth/routing,
fix that before sweeping.

### Full 20-task sweep per model

Give each run a descriptive `JOB_NAME` so the hub scoreboard is readable
(`<agent>-<model>`). Suggested `INFRA_PARALLEL=6` on an 8-GPU box.

```bash
# ---- claude-code (Anthropic gateway) ----
JOB_NAME=claude-opus-4.6   MODEL=claude-opus-4.6   INFRA_PARALLEL=6 ./run_claude_code.sh
JOB_NAME=claude-haiku-4.5  MODEL=claude-haiku-4.5  INFRA_PARALLEL=6 ./run_claude_code.sh
JOB_NAME=claude-sonnet-5   MODEL=Claude-Sonnet-5   INFRA_PARALLEL=6 ./run_claude_code.sh
JOB_NAME=claude-opus-4.8   MODEL=claude-opus-4.8   INFRA_PARALLEL=6 ./run_claude_code.sh

# ---- codex (AMD Unified, provider=openai) ----
JOB_NAME=codex-gpt-5.6-sol   MODEL=gpt-5.6-sol   INFRA_PARALLEL=6 ./run_codex.sh
JOB_NAME=codex-gpt-5.6-luna  MODEL=gpt-5.6-luna  INFRA_PARALLEL=6 ./run_codex.sh
JOB_NAME=codex-gpt-5.5       MODEL=gpt-5.5       INFRA_PARALLEL=6 ./run_codex.sh
JOB_NAME=codex-gpt-5.6-terra MODEL=gpt-5.6-terra INFRA_PARALLEL=6 ./run_codex.sh

# ---- opencode (AMD Unified, provider=amd; chat adapter) ----
JOB_NAME=opencode-deepseek-v4-flash MODEL=DeepSeek-V4-Flash \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' INFRA_PARALLEL=6 ./run_open_code.sh
JOB_NAME=opencode-minimax-m2.7 MODEL=MiniMax-M2.7 \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' INFRA_PARALLEL=6 ./run_open_code.sh
JOB_NAME=opencode-kimi-k2.6 MODEL=Kimi-K2.6 \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' INFRA_PARALLEL=6 ./run_open_code.sh
JOB_NAME=opencode-qwen3.6-35b-a3b MODEL=Qwen3.6-35B-A3B \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' INFRA_PARALLEL=6 ./run_open_code.sh
JOB_NAME=opencode-gemini-3.5-flash MODEL=gemini-3.5-flash \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' INFRA_PARALLEL=6 ./run_open_code.sh
JOB_NAME=opencode-gemma-4-31b MODEL=Gemma-4-31B \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' INFRA_PARALLEL=6 ./run_open_code.sh

# ---- opencode (on-prem SGLang, provider=onprem; chat adapter) ----
JOB_NAME=opencode-glm-5.2-fp8-onprem MODEL=GLM-5.2-FP8 \
  AMD_OPENCODE_PROVIDER=onprem AMD_CODEX_BASE_URL=http://10.145.64.81:30000/v1 \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' INFRA_PARALLEL=4 ./run_open_code.sh

# ---- opencode (on-prem vLLM, provider=onprem; chat adapter) ----
JOB_NAME=opencode-minimax-m3-onprem MODEL=/models/MiniMax-M3 \
  AMD_OPENCODE_PROVIDER=onprem AMD_CODEX_BASE_URL=http://10.145.64.81:30000/v1 \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' INFRA_PARALLEL=4 ./run_open_code.sh
JOB_NAME=opencode-kimi-k2.7-code-onprem MODEL=/models/Kimi-K2.7-Code \
  AMD_OPENCODE_PROVIDER=onprem AMD_CODEX_BASE_URL=http://10.145.64.81:30000/v1 \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' INFRA_PARALLEL=4 ./run_open_code.sh

JOB_NAME=opencode-qwopus3.6-27b-coder-onprem MODEL=/models/Qwopus3.6-27B-Coder \
  AMD_OPENCODE_PROVIDER=onprem AMD_CODEX_BASE_URL=http://10.145.64.87:9527/v1 \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' INFRA_PARALLEL=4 \
  INFRABENCH_GPU_COUNT=6 ./run_open_code.sh

JOB_NAME=opencode-qwopus3.6-35b-a3b-coder-onprem MODEL=/models/Qwopus3.6-35B-A3B-Coder \
  AMD_OPENCODE_PROVIDER=onprem AMD_CODEX_BASE_URL=http://10.145.64.87:9528/v1 \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' INFRA_PARALLEL=4 \
  INFRABENCH_GPU_COUNT=6 ./run_open_code.sh

JOB_NAME=opencode-qwen3.5-397b-a17b-fp8-onprem MODEL=/models/Qwen3.5-397B-A17B-FP8 \
  AMD_OPENCODE_PROVIDER=onprem AMD_CODEX_BASE_URL=http://10.145.64.81:30000/v1 \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' INFRA_PARALLEL=4 \
  INFRABENCH_GPU_COUNT=6 ./run_open_code.sh

JOB_NAME=opencode-mimo-v2-flash-onprem MODEL=/models/MiMo-V2-Flash \
  AMD_OPENCODE_PROVIDER=onprem AMD_CODEX_BASE_URL=http://10.145.64.81:30000/v1 \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' INFRA_PARALLEL=4 \
  INFRABENCH_GPU_COUNT=6 ./run_open_code.sh

JOB_NAME=opencode-qwen3.5-122b-a10b-fp8-onprem MODEL=/models/Qwen3.5-122B-A10B-FP8 \
  AMD_OPENCODE_PROVIDER=onprem AMD_CODEX_BASE_URL=http://10.145.64.87:30000/v1 \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' INFRA_PARALLEL=4 \
  INFRABENCH_GPU_COUNT=6 ./run_open_code.sh

JOB_NAME=opencode-mimo-v2.5-pro-onprem MODEL=/models/MiMo-V2.5-Pro \
  AMD_OPENCODE_PROVIDER=onprem AMD_CODEX_BASE_URL=http://10.145.64.81:30000/v1 \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' INFRA_PARALLEL=4 \
  INFRABENCH_GPU_COUNT=6 ./run_open_code.sh
```

Each runner prints a `passed/total` summary and **exits nonzero** if any task
failed or produced no reward (safe for scripting/CI). Results land in
`jobs/<JOB_NAME>/<task>__<id>/`.

---

## What to collect per run

From `jobs/<JOB_NAME>/` (or the hub Jobs table):

- **reward** — `verifier/reward.txt` per task (`1`=pass, `0`=fail); the runner's
  `passed/total` is the headline score.
- **cost** — `result.json → agent_result.cost_usd` (claude/codex compute it
  natively; opencode via the injected per-model pricing block). The planned
  opencode model prices are prefilled in `run_open_code.sh`.

OpenCode pricing reference from LiteLLM, converted to USD per 1M tokens. Cache
read uses LiteLLM's `cache_read_input_token_cost` when present; otherwise it
falls back to the input rate in `run_open_code.sh`.

For `Qwen3.5-397B-A17B-FP8`, the exact LiteLLM TensorMesh key lists cache-read
as zero, but this plan accounts cache-read at the input rate (`$0.60/M`) for
conservative cross-run comparison.

For `Qwen3.5-122B-A10B-FP8`, the LiteLLM `openrouter/qwen/qwen3.5-122b-a10b`
key has no cache-read override, so this plan uses the input rate (`$0.40/M`) for
cache-read accounting.

| Model | LiteLLM source key | Input | Output | Cache read |
|---|---|---:|---:|---:|
| `DeepSeek-V4-Flash` | `deepseek-v4-flash` | 0.14 | 0.28 | 0.0028 |
| `MiniMax-M2.7` | `sambanova/MiniMax-M2.7` | 0.60 | 2.40 | 0.60 |
| `MiniMax-M3` | `minimax-m3` | 0.60 | 2.40 | 0.12 |
| `Kimi-K2.7-Code` | `kimi-k2.7-code` | 0.95 | 4.00 | 0.19 |
| `Kimi-K2.6` | `kimi-k2.6` | 0.95 | 4.00 | 0.16 |
| `Qwopus3.6-27B-Coder` | `libertai/qwen3.6-27b` | 0.15 | 0.50 | 0.15 |
| `Qwopus3.6-35B-A3B-Coder` | `scaleway/qwen/qwen3.6-35b-a3b` | 0.25 | 1.50 | 0.25 |
| `Qwen3.5-397B-A17B-FP8` | `tensormesh/Qwen/Qwen3.5-397B-A17B-FP8` | 0.60 | 3.60 | 0.60 |
| `Qwen3.5-122B-A10B-FP8` | `openrouter/qwen/qwen3.5-122b-a10b` | 0.40 | 2.00 | 0.40 |
| `MiMo-V2-Flash` | `openrouter/xiaomi/mimo-v2-flash` | 0.10 | 0.30 | 0.01 |
| `MiMo-V2.5-Pro` | `openrouter/xiaomi/mimo-v2.5-pro` | 1.00 | 3.00 | 0.20 |
| `Qwen3.6-27B` | `libertai/qwen3.6-27b` | 0.15 | 0.50 | 0.15 |
| `Qwen3.6-35B-A3B` | `scaleway/qwen/qwen3.6-35b-a3b` | 0.25 | 1.50 | 0.25 |
| `gemini-3.5-flash` | `gemini-3.5-flash` | 1.50 | 9.00 | 0.15 |
| `Gemma-4-31B` | `bedrock_mantle/google.gemma-4-31b` | 0.14 | 0.40 | 0.14 |
| `GLM-5.2-FP8` | `glm-5.2` | 1.40 | 4.40 | 0.26 |

- **latency** — `result.json` phase timings (`agent_execution`).
- **failure triage** — for reward-0: is it a genuine miss (verifier ran, see
  `verifier/test-stdout.txt`) or an infra/gateway error (`exception.txt` —
  `UnknownApiError`, `NonZeroAgentExitCodeError`, `AgentSetupTimeoutError`)?
  Infra errors are re-run candidates, not model failures.

Aggregate into an agent × model table: pass-rate (X/20), total cost, median
task latency.

---

## Known gotchas / notes for the tester

- **Model casing matters.** Use the exact catalog id (e.g. `Claude-Sonnet-5`,
  `DeepSeek-V4-Flash`, `Kimi-K2.6`, `Qwen3.6-35B-A3B`,
  `gemini-3.5-flash`, `Gemma-4-31B`). List the catalog with
  `curl -s $LLM_GATEWAY_URL/v1/models -H "Ocp-Apim-Subscription-Key: <key>" -H "ntid: <ntid>"`.
- **Do NOT provider-prefix the claude model** (`anthropic/claude-...`) — this
  claude-code build passes the model verbatim and the gateway 400s on it. Bare
  model only; claude's Providers hub column stays blank (cosmetic).
- **opencode reasoning vs chat adapter** — wrong adapter → 400
  "reasoning_effort not supported on /v1/chat/completions" (reasoning model on
  chat adapter) or a tool-call failure. Match per the adapter rule above.
- **On-prem GLM routing:** `GLM-5.2-FP8` is not routed through the AMD gateway in
  Round 4. Use `AMD_OPENCODE_PROVIDER=onprem`,
  `AMD_CODEX_BASE_URL=http://10.145.64.81:30000/v1`, and
  `AMD_OPENCODE_NPM='@ai-sdk/openai-compatible'`. The first `hello-rocm` smoke
  reached the server but failed because the model emitted a literal
  `<tool_call>...</tool_call>` text block instead of an OpenAI structured tool
  call. Restart the SGLang server with `--reasoning-parser glm45` and
  `--tool-call-parser glm47`, then rerun the smoke before starting the full GLM
  sweep. The recorded full sweep used `INFRA_PARALLEL=4`; an earlier 6-way
  attempt was abandoned after the host ran out of disk space while building and
  running task containers.
- **On-prem MiniMax-M3 routing:** `MiniMax-M3` is served by vLLM from
  `/home/xisun/InfraBench/minimax-m3-vllm/launch_vllm_minimax_m3_server.sh`.
  vLLM advertises the model id as `/models/MiniMax-M3`, not `MiniMax-M3`, so set
  `MODEL=/models/MiniMax-M3`. A smoke using `MODEL=MiniMax-M3` reaches the
  server but fails with `The model MiniMax-M3 does not exist`.
- **On-prem Kimi-K2.7-Code routing:** `Kimi-K2.7-Code` is served by vLLM from
  `/home/xisun/InfraBench/kimi-k2.7-code-vllm/launch_vllm_kimi_k2.7_code_server.sh`.
  The launch uses `--tool-call-parser kimi_k2`, `--enable-auto-tool-choice`, and
  `--reasoning-parser kimi_k2`. vLLM advertises only `/models/Kimi-K2.7-Code`,
  so set `MODEL=/models/Kimi-K2.7-Code` for OpenCode runs. `run_open_code.sh`
  strips the leading slash for the OpenCode model name
  (`onprem/models/Kimi-K2.7-Code`) and uses the bare provider catalog/display key
  `Kimi-K2.7-Code` so Harbor does not show `/models/...` as the model.
- **On-prem Qwopus3.6 routing:** `Qwopus3.6-27B-Coder` is served locally on GPU
  6 from `/home/xisun/InfraBench/qwopus3.6-27b/launch_qwopu3.6_27b_sgl.sh` at
  `http://10.145.64.87:9527/v1`, and `Qwopus3.6-35B-A3B-Coder` is served locally
  on GPU 7 from `/home/xisun/InfraBench/qwopus3.6-35b/launch_qwopus3.6_35b_sgl.sh`
  at `http://10.145.64.87:9528/v1`. SGLang advertises `/models/Qwopus3.6-27B-Coder`
  and `/models/Qwopus3.6-35B-A3B-Coder`, so use those exact `MODEL=` values.
  Always set `INFRABENCH_GPU_COUNT=6` for these sweeps so the InfraBench GPU
  allocator only hands GPUs 0-5 to task containers. Tool-call parser behavior
  differs by checkpoint: `Qwopus3.6-27B-Coder` emits Qwen JSON
  `<tool_call>...</tool_call>` blocks and needs `--tool-call-parser qwen25`;
  `Qwopus3.6-35B-A3B-Coder` emits `<function=...><parameter=...>` blocks and
  needs `--tool-call-parser qwen3_coder`. Direct local probes produced
  structured `tool_calls` with those parser settings. Harbor task containers
  must use the host-routable IP, not `127.0.0.1`; the `127.0.0.1` smokes timed
  out because localhost resolved inside the task container. Host-IP
  `hello-rocm` smokes passed for both Qwopus models. `run_open_code.sh`
  registers both the bare display key (`Qwopus3.6-...`) and the runtime
  `models/Qwopus3.6-...` key in OpenCode's provider config so cost accounting
  works while Harbor metadata can still be normalized to the bare model name
  before upload.
- **On-prem Qwen3.5-397B routing:** `Qwen3.5-397B-A17B-FP8` is served by SGLang
  from `/home/xisun/InfraBench/qwen3.5-397b-fp8/launch_sgl_qwen3.5_397b_server.sh`
  on another MI350 machine at `http://10.145.64.81:30000/v1`. SGLang advertises
  `/models/Qwen3.5-397B-A17B-FP8`, so use that exact `MODEL=` value. The launch
  uses `--reasoning-parser qwen3`, `--tool-call-parser qwen3_coder`,
  `--attention-backend aiter`, `--tp 4`, and `--dp 2`. Keep
  `INFRABENCH_GPU_COUNT=6` while the local Qwopus servers are running on GPUs
  6/7, even though the 397B model server itself is remote.
- **On-prem MiMo-V2-Flash routing:** `MiMo-V2-Flash` is served by SGLang from
  `/home/xisun/InfraBench/mimo-v2-flash-sgl/launch_sgl_mimo_v2_flash_server.sh`
  on another MI350 machine at `http://10.145.64.81:30000/v1`. SGLang advertises
  `/models/MiMo-V2-Flash`, so use that exact `MODEL=` value. The launch uses
  `--reasoning-parser qwen3`, `--tool-call-parser mimo`, `--tp-size 4`,
  `--dp-size 2`, and Triton attention backends. Keep `INFRABENCH_GPU_COUNT=6`
  while the local Qwopus servers are running on GPUs 6/7.
- **On-prem Qwen3.5-122B routing:** `Qwen3.5-122B-A10B-FP8` is served by SGLang
  from `/home/xisun/InfraBench/qwen3.5-122b-sgl/launch_sgl_qwen3.5_122b_server.sh`
  on this MI350 machine at `http://10.145.64.87:30000/v1`. SGLang advertises
  `/models/Qwen3.5-122B-A10B-FP8`, so use that exact `MODEL=` value. The launch
  uses `--reasoning-parser qwen3`, `--tool-call-parser qwen3_coder`,
  `--attention-backend aiter`, `--tp 2`, and GPUs 6/7 via
  `HIP_VISIBLE_DEVICES=6,7`. Keep `INFRABENCH_GPU_COUNT=6` so InfraBench task
  containers do not allocate those GPUs.
- **On-prem MiMo-V2.5-Pro routing:** `MiMo-V2.5-Pro` is served by SGLang from
  `/home/xisun/InfraBench/mimo-v2.5-pro-sgl/launch_sgl_mimo_v2.5_pro_server.sh`
  on another MI350 machine at `http://10.145.64.81:30000/v1`. SGLang advertises
  `/models/MiMo-V2.5-Pro`, so use that exact `MODEL=` value. The launch uses
  `--reasoning-parser mimo`, `--tool-call-parser mimo`, `--tp-size 8`,
  `--disable-custom-all-reduce`, and Triton attention backends. The pre-sweep
  endpoint checks passed (`sgl-eval ping`) and GSM8K scored 98.00% on 200
  examples. Keep `INFRABENCH_GPU_COUNT=6` while the local Qwopus servers are
  running on GPUs 6/7.
- **Backend flakiness (gateway-side, not our config):** if a model 404s/500s at
  the gateway, treat it as a backend outage; retry later or skip. The current
  opencode plan assumes `DeepSeek-V4-Flash`, `Kimi-K2.6`,
  `Qwen3.6-35B-A3B`, `gemini-3.5-flash`, and `Gemma-4-31B` are available in the
  AMD LLM gateway. `GLM-5.2-FP8` is skipped on the gateway until that deployment
  recovers; `Grok-4.3` is skipped until the gateway exposes a working model id
  or route for this runner.
- **Gateway pressure at high concurrency:** long agentic sessions occasionally
  drop (`UnknownApiError`, exit 143). If a sweep shows several such exceptions,
  lower `INFRA_PARALLEL` or add `-k 2` (auto-retry attempts).
- **Agent-setup timeout:** the runners pass `--agent-setup-timeout-multiplier 3`
  to absorb concurrent npm-install contention; override with
  `INFRA_SETUP_TIMEOUT_MULT`.
- **opencode secret handling:** the gateway key is embedded in `--ak
  opencode_config` and scrubbed from artifacts by an EXIT trap (runs even on
  interrupt). claude/codex pass it as leak-safe `--ae` env templates.

---

## Suggested execution order

1. Smoke test (hello-rocm) for all 3 agents → confirm auth.
2. Full sweep, one model at a time (serial across models; `INFRA_PARALLEL`
   parallelizes tasks within a model). 23 sweeps total, including the
   `DeepSeek-V4-Flash` opencode retest, the Round 4 on-prem GLM run, the
   Round 5 on-prem MiniMax-M3 run, and the Round 6 on-prem Kimi-K2.7-Code,
   Qwopus3.6-27B-Coder, and Qwopus3.6-35B-A3B-Coder runs, plus the Round 7
   on-prem Qwen3.5-397B-A17B-FP8 run, the Round 8 on-prem MiMo-V2-Flash run,
   the Round 9 on-prem Qwen3.5-122B-A10B-FP8 run, and the Round 10 on-prem
   MiMo-V2.5-Pro run.
3. Triage reward-0s: separate genuine misses from infra/gateway errors; re-run
   infra failures.
4. Build the agent × model scoreboard (pass-rate, cost, latency).
