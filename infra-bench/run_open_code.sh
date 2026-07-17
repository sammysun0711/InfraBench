#!/usr/bin/env bash
#
# Run InfraBench tasks with the OpenCode agent against the AMD LLM gateway
# (Unified endpoint). Like the AMD gateway for Codex, it needs a custom
# Ocp-Apim-Subscription-Key header — but harbor's OpenCode agent accepts an
# arbitrary `opencode_config` kwarg (deep-merged into opencode.json), so we inject
# a custom OpenAI-compatible provider ("amd") with the header there. No custom
# agent class needed (unlike run_codex.sh).
#
# The model must be provider-qualified: amd/<model> (e.g. amd/gpt-5.5). opencode
# fetches the @ai-sdk/openai-compatible provider at runtime.
#
# SECURITY: the subscription key is written into the injected provider config.
# harbor serializes agent kwargs into job artifacts, so unlike run_codex.sh's
# ${VAR} template trick (which only works for --ae env values, not --ak kwargs),
# this key CAN land in config.json. We therefore scrub it from the job dir after
# the run. Treat job artifacts as sensitive until scrubbed.
#
# Runs tasks/ as a LOCAL DATASET so the hub Jobs table fills every column
# (Datasets/Providers/Models/…). Use -i/-x to filter to specific tasks.
#
# Usage:
#   ./run_open_code.sh                                  # ALL 20 tasks (local dataset)
#   ./run_open_code.sh -i hello-rocm                    # one task (include filter)
#   ./run_open_code.sh -i hello-rocm -i mem-bandwidth-bench   # a few tasks
#   MODEL=gemini-3.1-pro-preview AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' ./run_open_code.sh -i hello-rocm
#   INFRA_PARALLEL=6 ./run_open_code.sh                # harbor -n concurrency
#
# Model→adapter (AMD_OPENCODE_NPM): reasoning models (gpt-5.x) need the Responses
# API → @ai-sdk/openai (default); chat models (gemini/deepseek/kimi) →
# @ai-sdk/openai-compatible.
#   Extra args pass straight through to `harbor run`.
set -euo pipefail

ENV_FILE="${ENV_FILE:-/home/xisun/setup_env.sh}"
MODEL="${MODEL:-gpt-5.5}"
PROVIDER_ID="${AMD_OPENCODE_PROVIDER:-amd}"
GATEWAY_BASE_URL="${AMD_CODEX_BASE_URL:-https://llm-api.amd.com/Unified/v1}"
# AI-SDK adapter (opencode `npm`). Reasoning models (gpt-5.5) need the Responses
# API → @ai-sdk/openai. Plain chat models (Kimi-K2.7-Code) use chat/completions →
# @ai-sdk/openai-compatible. Override per model with AMD_OPENCODE_NPM.
OPENCODE_NPM="${AMD_OPENCODE_NPM:-@ai-sdk/openai}"

export INFRABENCH_GPU_POOL_HOST="${INFRABENCH_GPU_POOL_HOST:-/tmp/infrabench_gpu_pool}"
export INFRABENCH_GPU_COUNT="${INFRABENCH_GPU_COUNT:-8}"
export INFRABENCH_MODELS_HOST="${INFRABENCH_MODELS_HOST:-/data/models}"
mkdir -p "$INFRABENCH_GPU_POOL_HOST"; chmod 777 "$INFRABENCH_GPU_POOL_HOST"

[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

: "${NTID:?NTID not set (check $ENV_FILE)}"
AMD_GATEWAY_SUBKEY="${AMD_GATEWAY_SUBKEY:-${AMD_CODEX_SUBKEY:-}}"
if [[ -z "$AMD_GATEWAY_SUBKEY" && -f "$HOME/.codex/config.toml" ]]; then
  AMD_GATEWAY_SUBKEY="$(sed -nE 's/.*"Ocp-Apim-Subscription-Key"[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' "$HOME/.codex/config.toml" | head -1)"
fi
: "${AMD_GATEWAY_SUBKEY:?could not resolve gateway subkey (set AMD_GATEWAY_SUBKEY or configure ~/.codex/config.toml)}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Build the opencode provider-config JSON. Registers a custom OpenAI-compatible
# provider that carries the required header + base URL, and declares the model so
# opencode won't reject it as unknown.
OPENCODE_CONFIG="$(python3 - "$PROVIDER_ID" "$GATEWAY_BASE_URL" "$MODEL" "$AMD_GATEWAY_SUBKEY" "$NTID" "$OPENCODE_NPM" <<'PY'
import json, sys
provider, base_url, model, subkey, ntid, npm = sys.argv[1:7]

# opencode computes Cost USD from a per-model `cost` block (USD per MILLION
# tokens). Fields: input (= cache-MISS input rate), output, cache_read (= cache-
# HIT input rate; equals input when the vendor doesn't distinguish). Custom
# providers have no models.dev pricing, so without this the hub "Cost USD" column
# is blank. Matched by case-insensitive substring, longest key first.
PRICING = {
    # DeepSeek + GLM: vendor-published prices from price.md (separate cache-hit
    # via cache_read vs cache-miss via input). DeepSeek also matches litellm.
    "deepseek-v4-flash": {"input": 0.14,  "output": 0.28, "cache_read": 0.0028},
    "deepseek-v4-pro":   {"input": 0.435, "output": 0.87, "cache_read": 0.003625},
    "deepseek":          {"input": 0.14,  "output": 0.28, "cache_read": 0.0028},
    "glm-5.2":           {"input": 1.4,   "output": 4.4,  "cache_read": 0.26},
    "glm":               {"input": 1.4,   "output": 4.4,  "cache_read": 0.26},
    # GPT + Gemini: authoritative rates from LiteLLM's model_cost table (the same
    # source harbor's codex agent uses), pulled 2026-07-17 (USD per 1M tokens).
    "gpt-5.5":       {"input": 5.0,  "output": 30.0, "cache_read": 0.5},
    "gpt-5.6":       {"input": 5.0,  "output": 30.0, "cache_read": 0.5},
    "gpt-5":         {"input": 1.25, "output": 10.0, "cache_read": 0.125},
    "gpt-4.1":       {"input": 2.0,  "output": 8.0,  "cache_read": 0.5},
    "gpt-4o":        {"input": 2.5,  "output": 10.0, "cache_read": 1.25},
    "gemini-3.1-pro":{"input": 2.0,  "output": 12.0, "cache_read": 0.2},
    "gemini-2.5-pro":{"input": 1.25, "output": 10.0, "cache_read": 0.125},
    "gemini-2.5-flash":{"input": 0.30, "output": 2.5, "cache_read": 0.03},
    # Kimi: vendor-published prices from price.md (input = cache-MISS, cache_read
    # = cache-HIT). Longest key first so k2.7-code-highspeed beats k2.7-code.
    "kimi-k2.7-code-highspeed": {"input": 1.90, "output": 8.0,  "cache_read": 0.38},
    "kimi-k2.7-code":           {"input": 0.95, "output": 4.0,  "cache_read": 0.19},
    "kimi-k2.6":                {"input": 0.95, "output": 4.0,  "cache_read": 0.16},
    "kimi-k2.5":                {"input": 0.60, "output": 3.0,  "cache_read": 0.10},
    "kimi-k3":                  {"input": 3.0,  "output": 15.0, "cache_read": 0.30},
    "kimi":                     {"input": 0.95, "output": 4.0,  "cache_read": 0.19},
    # NOTE: gemini-3.5-pro-preview intentionally omitted — no public price yet.
}
def price(m):
    ml = m.lower()
    # Longest key first so 'deepseek-v4-flash' wins over 'deepseek'.
    for k in sorted(PRICING, key=len, reverse=True):
        if k in ml:
            return PRICING[k]
    return None  # unknown model → no cost block (leave hub Cost USD blank)

# npm picks the endpoint: @ai-sdk/openai → /v1/responses (reasoning models like
# gpt-5.5); @ai-sdk/openai-compatible → /v1/chat/completions (plain chat models
# like Kimi-K2.7-Code). Override with AMD_OPENCODE_NPM.
cfg = {
    "provider": {
        provider: {
            "npm": npm,
            "name": "AMD LLM Gateway",
            "options": {
                "baseURL": base_url,
                # @ai-sdk/openai validates a non-empty apiKey before sending, even
                # though the gateway authenticates via the Ocp-Apim header below.
                # Use a placeholder so the SDK proceeds; real auth is the header.
                "apiKey": "amd-gateway",
                "headers": {
                    "Ocp-Apim-Subscription-Key": subkey,
                    "ntid": ntid,
                },
            },
            "models": {model: ({"cost": price(model)} if price(model) else {})},
        }
    }
}
print(json.dumps(cfg))
PY
)"

# Model must be provider-qualified for opencode's provider/model split.
QUALIFIED_MODEL="${PROVIDER_ID}/${MODEL}"

AGENT_ARGS=(
  -a opencode
  -m "$QUALIFIED_MODEL"
  --ak "opencode_config=${OPENCODE_CONFIG}"
)

# Scrub the subkey from a finished job dir (opencode_config lands in artifacts).
_scrub() {
  local dir="$1"
  [[ -n "$AMD_GATEWAY_SUBKEY" && -d "$dir" ]] || return 0
  grep -rlF "$AMD_GATEWAY_SUBKEY" "$dir" 2>/dev/null | while read -r f; do
    python3 - "$f" "$AMD_GATEWAY_SUBKEY" <<'PY'
import sys
f, key = sys.argv[1], sys.argv[2]
try:
    t = open(f, "r", errors="surrogateescape").read()
except Exception:
    sys.exit(0)
if key in t:
    open(f, "w", errors="surrogateescape").write(t.replace(key, "<REDACTED_GATEWAY_KEY>"))
PY
  done
}

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
# task.source="infra-bench" (hub "Datasets" column); the provider/model split
# fills "Providers"/"Models". One job, harbor's native -n concurrency (default
# 4). Pass -i <task>/-x <task> to filter.
JOB_NAME="${JOB_NAME:-$(date +%Y-%m-%d__%H-%M-%S)}"
JOBS_ROOT="${SCRIPT_DIR}/jobs"
JOBS_DIR="${JOBS_ROOT}/${JOB_NAME}"       # harbor creates this from --job-name
CONCURRENCY="${INFRA_PARALLEL:-4}"
mkdir -p "$JOBS_DIR"
echo "[run_open_code.sh] running tasks/ as a local dataset → ${JOBS_DIR} (n=${CONCURRENCY}, model=${QUALIFIED_MODEL})"

# -o = jobs ROOT; --job-name is the single subdir harbor creates under it
# (passing -o "$JOBS_DIR" too would double-nest jobs/<JOB>/<JOB>/).
# --agent-setup-timeout-multiplier absorbs the concurrent agent-setup (npm
# install) contention that harbor's native -n can trigger (AgentSetupTimeoutError).
harbor run "${AGENT_ARGS[@]}" \
  -p "$DATASET_DIR" \
  -n "$CONCURRENCY" \
  --agent-setup-timeout-multiplier "${INFRA_SETUP_TIMEOUT_MULT:-3}" \
  -o "$JOBS_ROOT" --job-name "$JOB_NAME" "$@" \
  2>&1 | tee "${JOBS_DIR}/run.log" || true

# opencode_config carries the subkey and lands in job artifacts — scrub it.
_scrub "$JOBS_DIR"

echo "[run_open_code.sh] done → ${JOBS_DIR}"
echo "[run_open_code.sh] rewards:"
total=0; passed=0
for r in "${JOBS_DIR}"/*/verifier/reward.txt; do
  [[ -f "$r" ]] || continue
  val="$(cat "$r")"
  echo "  $(basename "$(dirname "$(dirname "$r")")"): ${val}"
  total=$((total + 1))
  [[ "$val" == "1" ]] && passed=$((passed + 1))
done
echo "[run_open_code.sh] ${passed}/${total} passed"
