#!/usr/bin/env bash
#
# Run InfraBench tasks with harbor through the AMD internal LLM gateway.
#
# Handles two things harbor doesn't do on its own:
#   1. Gateway auth — injects ANTHROPIC_CUSTOM_HEADERS via --ae (harbor forwards
#      base URL + key but not the subscription header the AMD gateway needs).
#   2. GPU pool — exports the shared host pool dir so each task's
#      docker-compose.yaml can bind-mount it (${INFRABENCH_GPU_POOL_HOST}), and
#      the pool size so the allocator knows how many GPUs exist.
#
# Usage:
#   ./run.sh                                  # all tasks in tasks/
#   ./run.sh -p tasks/hello-rocm              # one task package
#   ./run.sh -a oracle -p tasks/hello-rocm    # oracle (sanity-check a task)
#   ./run.sh -p tasks/hello-rocm -k 3 -n 4    # 3 attempts, 4 concurrent
#   Any extra args pass straight through to `harbor run`.
set -euo pipefail

# --- config -----------------------------------------------------------------
ENV_FILE="${ENV_FILE:-/home/xisun/setup_env.sh}"
AGENT="${AGENT:-claude-code}"
MODEL="${MODEL:-claude-opus-4.8}"
# GPU pool: shared host dir for cross-trial flock arbitration, and total GPUs.
export INFRABENCH_GPU_POOL_HOST="${INFRABENCH_GPU_POOL_HOST:-/tmp/infrabench_gpu_pool}"
export INFRABENCH_GPU_COUNT="${INFRABENCH_GPU_COUNT:-8}"
mkdir -p "$INFRABENCH_GPU_POOL_HOST"
chmod 777 "$INFRABENCH_GPU_POOL_HOST"
# Pre-downloaded models, mounted read-only into model-dependent tasks so agents
# reuse weights instead of re-downloading each run.
export INFRABENCH_MODELS_HOST="${INFRABENCH_MODELS_HOST:-/data/models}"

# --- load gateway credentials ----------------------------------------------
if [[ ! -f "$ENV_FILE" ]]; then
  echo "error: env file not found: $ENV_FILE" >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$ENV_FILE"

: "${AMD_LLM_GATEWAY_KEY:?AMD_LLM_GATEWAY_KEY not set (check $ENV_FILE)}"
: "${NTID:?NTID not set (check $ENV_FILE)}"
: "${ANTHROPIC_BASE_URL:?ANTHROPIC_BASE_URL not set (check $ENV_FILE)}"

CUSTOM_HEADERS="Ocp-Apim-Subscription-Key: ${AMD_LLM_GATEWAY_KEY}, user: ${NTID}"

# Re-export after sourcing (setup_env.sh must not clobber these).
export INFRABENCH_GPU_POOL_HOST INFRABENCH_GPU_COUNT INFRABENCH_MODELS_HOST

# --- default target: all task packages under tasks/ -------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_PATH_ARGS=()
if [[ "$*" != *"-p"* && "$*" != *"--path"* ]]; then
  for t in "$SCRIPT_DIR"/tasks/*/; do
    [[ -f "$t/task.toml" ]] && DEFAULT_PATH_ARGS+=(-p "$t")
  done
fi

# --- run --------------------------------------------------------------------
# oracle agent ignores model/gateway args; only pass them for real agents.
AGENT_ARGS=(-a "$AGENT")
if [[ "$AGENT" != "oracle" ]]; then
  AGENT_ARGS+=(
    -m "$MODEL"
    --ae "ANTHROPIC_CUSTOM_HEADERS=${CUSTOM_HEADERS}"
    --ae "ANTHROPIC_BASE_URL=${ANTHROPIC_BASE_URL}"
  )
fi

exec harbor run \
  "${AGENT_ARGS[@]}" \
  "${DEFAULT_PATH_ARGS[@]}" \
  "$@"
