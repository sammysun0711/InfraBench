# InfraBench Cross-Agent × Model Test Plan

Goal: run the full 20-task InfraBench suite across three agents, each driving
several models through the AMD LLM gateway, and collect a comparable
agent × model scoreboard (reward, cost, latency) on the Harbor hub.

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

All 14 planned models are available in the AMD LLM gateway catalog
(`/v1/models`).

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
> MiniMax-M2.7, Kimi-K2.6, Qwen3.6-35B-A3B, gemini-3.5-flash, and
> Gemma-4-31B) are treated as chat models → always pass
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

| Model | LiteLLM source key | Input | Output | Cache read |
|---|---|---:|---:|---:|
| `DeepSeek-V4-Flash` | `deepseek-v4-flash` | 0.14 | 0.28 | 0.0028 |
| `MiniMax-M2.7` | `sambanova/MiniMax-M2.7` | 0.60 | 2.40 | 0.60 |
| `Kimi-K2.6` | `kimi-k2.6` | 0.95 | 4.00 | 0.16 |
| `Qwen3.6-35B-A3B` | `scaleway/qwen/qwen3.6-35b-a3b` | 0.25 | 1.50 | 0.25 |
| `gemini-3.5-flash` | `gemini-3.5-flash` | 1.50 | 9.00 | 0.15 |
| `Gemma-4-31B` | `bedrock_mantle/google.gemma-4-31b` | 0.14 | 0.40 | 0.14 |

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
- **Backend flakiness (gateway-side, not our config):** if a model 404s/500s at
  the gateway, treat it as a backend outage; retry later or skip. The current
  opencode plan assumes `DeepSeek-V4-Flash`, `Kimi-K2.6`,
  `Qwen3.6-35B-A3B`, `gemini-3.5-flash`, and `Gemma-4-31B` are available in the
  AMD LLM gateway. `Grok-4.3` is skipped until the gateway exposes a working
  model id or route for this runner.
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
   parallelizes tasks within a model). 14 sweeps total, including the
   `DeepSeek-V4-Flash` opencode retest.
3. Triage reward-0s: separate genuine misses from infra/gateway errors; re-run
   infra failures.
4. Build the agent × model scoreboard (pass-rate, cost, latency).
