#!/usr/bin/env bash
#
# Run InfraBench tasks with the Codex CLI against the AMD LLM gateway (Unified
# endpoint), which needs a custom Ocp-Apim-Subscription-Key header that harbor's
# stock codex agent can't send. We use the custom AmdCodex agent
# (agents/amd_codex.py) which injects an [model_providers.amd] block into codex's
# config.toml.
#
# SECURITY: like run_claude_code.sh, the subscription key is exported as a host env var and
# passed as a TEMPLATE ('${AMD_GATEWAY_SUBKEY}') so harbor stores the template —
# never the literal key — in config.json/lock.json/result.json, and resolves it
# from the host env at run time.
#
# Runs tasks/ as a LOCAL DATASET so the hub Jobs table fills every column
# (Datasets/Models/…). Use -i/-x to filter to specific tasks.
#
# Usage:
#   ./run_codex.sh                                     # ALL 20 tasks (local dataset)
#   ./run_codex.sh -i hello-rocm                       # one task (include filter)
#   ./run_codex.sh -i hello-rocm -k 2                  # 2 attempts
#   MODEL=gpt-5.6-sol ./run_codex.sh                   # override model
#   INFRA_PARALLEL=6 ./run_codex.sh                    # harbor -n concurrency
#   Extra args pass straight through to `harbor run`.
set -euo pipefail

ENV_FILE="${ENV_FILE:-/home/xisun/setup_env.sh}"
MODEL="${MODEL:-gpt-5.5}"
GATEWAY_BASE_URL="${AMD_CODEX_BASE_URL:-https://llm-api.amd.com/Unified/v1}"

# GPU pool + models (same as run_claude_code.sh).
export INFRABENCH_GPU_POOL_HOST="${INFRABENCH_GPU_POOL_HOST:-/tmp/infrabench_gpu_pool}"
export INFRABENCH_GPU_COUNT="${INFRABENCH_GPU_COUNT:-8}"
export INFRABENCH_MODELS_HOST="${INFRABENCH_MODELS_HOST:-/data/models}"
mkdir -p "$INFRABENCH_GPU_POOL_HOST"; chmod 777 "$INFRABENCH_GPU_POOL_HOST"

[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

# Resolve the gateway subscription key + ntid. Prefer explicit vars, then fall
# back to the values already configured in ~/.codex/config.toml.
: "${NTID:?NTID not set (check $ENV_FILE)}"
AMD_GATEWAY_SUBKEY="${AMD_GATEWAY_SUBKEY:-${AMD_CODEX_SUBKEY:-}}"
if [[ -z "$AMD_GATEWAY_SUBKEY" && -f "$HOME/.codex/config.toml" ]]; then
  AMD_GATEWAY_SUBKEY="$(sed -nE 's/.*"Ocp-Apim-Subscription-Key"[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' "$HOME/.codex/config.toml" | head -1)"
fi
: "${AMD_GATEWAY_SUBKEY:?could not resolve gateway subkey (set AMD_GATEWAY_SUBKEY or configure ~/.codex/config.toml)}"

export AMD_GATEWAY_SUBKEY
export AMD_GATEWAY_NTID="${NTID}"
export OPENAI_BASE_URL="$GATEWAY_BASE_URL"

# Custom agent import path (repo-relative module). PYTHONPATH so harbor can import it.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PYTHONPATH="${SCRIPT_DIR}:${PYTHONPATH:-}"
AGENT_IMPORT="agents.amd_codex:AmdCodex"

# Pass secrets/base-url as TEMPLATES (single quotes) — harbor resolves from host
# env at run time and never writes the literal key to any artifact.
AGENT_ARGS=(
  -a "$AGENT_IMPORT"
  -m "$MODEL"
  --ae 'AMD_GATEWAY_SUBKEY=${AMD_GATEWAY_SUBKEY}'
  --ae 'AMD_GATEWAY_NTID=${AMD_GATEWAY_NTID}'
  --ae 'OPENAI_BASE_URL=${OPENAI_BASE_URL}'
)

# harbor labels a local dataset by the -p directory's basename (task.source →
# hub "Datasets" column). Stage a dir literally named infra-bench with symlinks
# to each real task so the label is "infra-bench", not "tasks".
DATASET_NAME="${INFRA_DATASET_NAME:-infra-bench}"
_stage="$(mktemp -d)/${DATASET_NAME}"
mkdir -p "$_stage"
for _t in "$SCRIPT_DIR"/tasks/*/; do
  [[ -f "${_t}task.toml" ]] && ln -s "$(cd "$_t" && pwd)" "$_stage/$(basename "$_t")"
done
DATASET_DIR="$_stage"
trap 'rm -rf "$(dirname "$_stage")"' EXIT

# Run the tasks as a LOCAL DATASET. harbor stamps each trial with
# task.source="infra-bench" (hub "Datasets" column); the model fills "Models".
# One job, harbor's native -n concurrency (default 4). Use -i/-x to filter.
JOB_NAME="${JOB_NAME:-codex-$(date +%Y-%m-%d__%H-%M-%S)}"
JOBS_ROOT="${SCRIPT_DIR}/jobs"
JOBS_DIR="${JOBS_ROOT}/${JOB_NAME}"       # harbor creates this from --job-name
CONCURRENCY="${INFRA_PARALLEL:-4}"
mkdir -p "$JOBS_DIR"
echo "[run_codex.sh] running tasks/ as a local dataset → ${JOBS_DIR} (n=${CONCURRENCY}, model=${MODEL})"

# -o = jobs ROOT; --job-name is the single subdir harbor creates under it
# (passing -o "$JOBS_DIR" too would double-nest jobs/<JOB>/<JOB>/).
# --agent-setup-timeout-multiplier absorbs concurrent agent-setup (npm install)
# contention that harbor's native -n can trigger (AgentSetupTimeoutError).
harbor run "${AGENT_ARGS[@]}" \
  -p "$DATASET_DIR" \
  -n "$CONCURRENCY" \
  --agent-setup-timeout-multiplier "${INFRA_SETUP_TIMEOUT_MULT:-3}" \
  -o "$JOBS_ROOT" --job-name "$JOB_NAME" "$@" \
  2>&1 | tee "${JOBS_DIR}/run.log" || true

echo "[run_codex.sh] done → ${JOBS_DIR}"
echo "[run_codex.sh] rewards:"
total=0; passed=0
for r in "${JOBS_DIR}"/*/verifier/reward.txt; do
  [[ -f "$r" ]] || continue
  val="$(cat "$r")"
  echo "  $(basename "$(dirname "$(dirname "$r")")"): ${val}"
  total=$((total + 1))
  [[ "$val" == "1" ]] && passed=$((passed + 1))
done
echo "[run_codex.sh] ${passed}/${total} passed"
