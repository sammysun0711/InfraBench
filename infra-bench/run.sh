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

# If the caller passed an explicit -p/--path, run a single harbor job verbatim.
# Scan args token by token (not a substring match on "$*") so an argument VALUE
# that merely contains "-p" (e.g. a model name) can't flip us out of all-task
# mode.
explicit_path=false
for arg in "$@"; do
  case "$arg" in
    -p|--path|--path=*) explicit_path=true; break ;;
  esac
done
if [[ "$explicit_path" == true ]]; then
  exec harbor run "${AGENT_ARGS[@]}" "$@"
fi

# No -p given → run EVERY task package under tasks/ as its own harbor job.
# harbor's `run` keeps only the LAST -p when several are passed, and its dataset
# model is registry-based (no clean offline path), so we launch one single-task
# harbor job per package and run up to INFRA_PARALLEL of them concurrently. The
# GPU-pool allocator (flock per card) makes concurrent trials safe: each job's
# trial claims its own GPU.
JOB_NAME="${JOB_NAME:-$(date +%Y-%m-%d__%H-%M-%S)}"
JOBS_DIR="${SCRIPT_DIR}/jobs/${JOB_NAME}"
PARALLEL="${INFRA_PARALLEL:-4}"
mkdir -p "$JOBS_DIR"
echo "[run.sh] running all tasks under tasks/ into ${JOBS_DIR} (parallel=${PARALLEL})"

for t in "$SCRIPT_DIR"/tasks/*/; do
  [[ -f "$t/task.toml" ]] || continue
  name="$(basename "$t")"
  # throttle: wait if PARALLEL jobs already running. `wait -n` returns the
  # finished job's exit status; a failed harbor job must NOT abort the launcher
  # under `set -e`, so swallow it (per-task success is read from reward.txt).
  while (( $(jobs -rp | wc -l) >= PARALLEL )); do wait -n || true; done
  echo "[run.sh] launching TASK: ${name}"
  # Each task gets its OWN --job-name (= task name) so concurrent jobs don't
  # collide on harbor's auto timestamped job dir. Output lands in
  # ${JOBS_DIR}/${name}/.
  ( harbor run "${AGENT_ARGS[@]}" -p "$t" -o "$JOBS_DIR" --job-name "$name" "$@" \
      > "${JOBS_DIR}/${name}.runlog" 2>&1 ) &
  # Stagger launches so concurrent trials don't all hit the agent-setup phase
  # (claude-code npm install) at the same instant. A simultaneous batch of
  # installs saturates network/disk and blows the 360s agent-setup timeout
  # (AgentSetupTimeoutError). A short gap lets each install get a head start.
  sleep "${INFRA_LAUNCH_STAGGER:-20}"
done
# Wait for every remaining job; ignore nonzero so we always reach the summary.
wait || true
echo "[run.sh] all tasks done → ${JOBS_DIR}"
echo "[run.sh] rewards:"
total=0; passed=0
for r in "${JOBS_DIR}"/*/*/verifier/reward.txt; do
  [[ -f "$r" ]] || continue
  val="$(cat "$r")"
  echo "  $(basename "$(dirname "$(dirname "$r")")"): ${val}"
  total=$((total + 1))
  [[ "$val" == "1" ]] && passed=$((passed + 1))
done
echo "[run.sh] ${passed}/${total} passed"

# Exit nonzero if any task failed or no rewards were produced, so CI/automation
# does not treat a failed (or empty) benchmark sweep as success.
if (( total == 0 )); then
  echo "[run.sh] ERROR: no reward files found — sweep produced no results" >&2
  exit 1
fi
if (( passed != total )); then
  echo "[run.sh] FAILED: $((total - passed)) task(s) did not pass" >&2
  exit 1
fi
