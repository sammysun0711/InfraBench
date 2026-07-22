#!/usr/bin/env bash
#
# Run InfraBench tasks with the claude-code agent via harbor, through the AMD
# internal LLM gateway. (For the Codex agent, use run_codex.sh.)
#
# Handles two things harbor doesn't do on its own:
#   1. Gateway auth — injects ANTHROPIC_CUSTOM_HEADERS via --ae (harbor forwards
#      base URL + key but not the subscription header the AMD gateway needs).
#   2. GPU pool — exports the shared host pool dir so each task's
#      docker-compose.yaml can bind-mount it (${INFRABENCH_GPU_POOL_HOST}), and
#      the pool size so the allocator knows how many GPUs exist.
#
# Runs tasks/ as a LOCAL DATASET so the hub Jobs table fills every column
# (Datasets/Models/…). Use -i/-x to filter to specific tasks.
#
# Usage:
#   ./run_claude_code.sh                                  # ALL 20 tasks (local dataset)
#   ./run_claude_code.sh -i hello-rocm                    # one task (include filter)
#   AGENT=oracle ./run_claude_code.sh -i hello-rocm       # oracle (sanity-check a task)
#   ./run_claude_code.sh -i hello-rocm -k 3               # 3 attempts
#   INFRA_PARALLEL=6 ./run_claude_code.sh                 # harbor -n concurrency
#   Any extra args pass straight through to `harbor run`.
set -euo pipefail

# --- config -----------------------------------------------------------------
ENV_FILE="${ENV_FILE:-${HOME:?HOME not set}/setup_env.sh}"
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

# SECURITY: do NOT pass the gateway key as a literal --ae value. harbor persists
# agent env into config.json/lock.json/result.json and only auto-redacts vars
# whose NAME matches (KEY|SECRET|TOKEN|PASSWORD|CREDENTIAL|AUTH). The header var
# is named ANTHROPIC_CUSTOM_HEADERS (no such word), so a literal value leaks the
# key into every job artifact. Instead we export the header as a host env var and
# pass the *template* '${ANTHROPIC_CUSTOM_HEADERS}': harbor stores the template
# literally (no secret on disk) and resolves it from the host env at agent start
# (harbor/agents/factory.py resolve_env_vars). Same for the base URL.
export ANTHROPIC_CUSTOM_HEADERS="Ocp-Apim-Subscription-Key: ${AMD_LLM_GATEWAY_KEY}, user: ${NTID}"

# Re-export after sourcing (setup_env.sh must not clobber these).
export INFRABENCH_GPU_POOL_HOST INFRABENCH_GPU_COUNT INFRABENCH_MODELS_HOST ANTHROPIC_BASE_URL

# --- agent args -------------------------------------------------------------
# oracle agent ignores model/gateway args; only pass them for real agents.
AGENT_ARGS=(-a "$AGENT")
if [[ "$AGENT" != "oracle" ]]; then
  # Pass TEMPLATES, not values — harbor resolves them from the host env at run
  # time and never writes the resolved secret to any job artifact. Single quotes
  # are intentional: the literal string ${VAR} must reach harbor unexpanded.
  AGENT_ARGS+=(
    -m "$MODEL"
    --ae 'ANTHROPIC_CUSTOM_HEADERS=${ANTHROPIC_CUSTOM_HEADERS}'
    --ae 'ANTHROPIC_BASE_URL=${ANTHROPIC_BASE_URL}'
  )
fi

# --- run --------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# harbor labels a local dataset by the -p directory's basename (task.source =
# path.resolve().name → the hub "Datasets" column). Pointing -p at tasks/ would
# label it "tasks"; we want "infra-bench". So stage a dir literally named
# infra-bench containing symlinks to each real task, and point -p there.
DATASET_DIR="${SCRIPT_DIR}/tasks"
DATASET_NAME="${INFRA_DATASET_NAME:-infra-bench}"
if [[ "$(basename "$DATASET_DIR")" != "$DATASET_NAME" ]]; then
  _stage="$(mktemp -d)/${DATASET_NAME}"
  mkdir -p "$_stage"
  for _t in "$SCRIPT_DIR"/tasks/*/; do
    [[ -f "${_t}task.toml" ]] && ln -s "$(cd "$_t" && pwd)" "$_stage/$(basename "$_t")"
  done
  DATASET_DIR="$_stage"
  trap 'rm -rf "$(dirname "$_stage")"' EXIT
fi

# Run the tasks as a LOCAL DATASET (-p "$DATASET_DIR"). harbor stamps each trial
# with task.source="infra-bench", populating the hub "Datasets" column; the model
# fills "Models". One job, harbor's native -n concurrency (default 4). Use
# -i <task>/-x <task> to filter; extra args pass to harbor run. The GPU-pool
# allocator (flock per card) keeps concurrent trials safe.
JOB_NAME="${JOB_NAME:-$(date +%Y-%m-%d__%H-%M-%S)}"
JOBS_ROOT="${SCRIPT_DIR}/jobs"
JOBS_DIR="${JOBS_ROOT}/${JOB_NAME}"       # harbor creates this from --job-name
CONCURRENCY="${INFRA_PARALLEL:-4}"
mkdir -p "$JOBS_DIR"
echo "[run_claude_code.sh] running tasks/ as a local dataset → ${JOBS_DIR} (n=${CONCURRENCY}, agent=${AGENT}, model=${MODEL})"

# -o points at the jobs ROOT; --job-name is the single subdir harbor creates
# under it (passing -o "$JOBS_DIR" too would double-nest jobs/<JOB>/<JOB>/).
# --agent-setup-timeout-multiplier absorbs concurrent agent-setup (claude-code
# npm install) contention that harbor's native -n can trigger
# (AgentSetupTimeoutError).
harbor run "${AGENT_ARGS[@]}" \
  -p "$DATASET_DIR" \
  -n "$CONCURRENCY" \
  --agent-setup-timeout-multiplier "${INFRA_SETUP_TIMEOUT_MULT:-3}" \
  -o "$JOBS_ROOT" --job-name "$JOB_NAME" "$@" \
  2>&1 | tee "${JOBS_DIR}/run.log" || true

echo "[run_claude_code.sh] done → ${JOBS_DIR}"
echo "[run_claude_code.sh] rewards:"
total=0; passed=0
for r in "${JOBS_DIR}"/*/verifier/reward.txt; do
  [[ -f "$r" ]] || continue
  val="$(cat "$r")"
  echo "  $(basename "$(dirname "$(dirname "$r")")"): ${val}"
  total=$((total + 1))
  [[ "$val" == "1" ]] && passed=$((passed + 1))
done
echo "[run_claude_code.sh] ${passed}/${total} passed"

# Exit nonzero if any task failed or no rewards were produced, so CI/automation
# does not treat a failed (or empty) benchmark sweep as success.
if (( total == 0 )); then
  echo "[run_claude_code.sh] ERROR: no reward files found — sweep produced no results" >&2
  exit 1
fi
if (( passed != total )); then
  echo "[run_claude_code.sh] FAILED: $((total - passed)) task(s) did not pass" >&2
  exit 1
fi
