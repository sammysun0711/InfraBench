#!/usr/bin/env bash
#
# Analyze Terminal-Bench trial trajectories with the claude-code evaluator
# through the AMD internal LLM gateway instead of the public Anthropic API.
#
# Like `harbor run`, `harbor analyze` spawns a claude-code agent in a container
# but does NOT forward ANTHROPIC_CUSTOM_HEADERS, so we inject the gateway
# subscription header explicitly with `--ae`.
#
# Usage:
#   ./analyze.sh jobs/2026-07-05__07-09-50/          # analyze a whole job
#   ./analyze.sh jobs/2026-07-05__07-09-50/regex-chess__DhXyi8C   # one trial
#   ./analyze.sh jobs/<job> --failing                # only failing trials
#   ./analyze.sh jobs/<job> -r my-rubric.toml        # custom rubric
#   Any extra args are passed straight through to `harbor analyze`.
set -euo pipefail

# --- config -----------------------------------------------------------------
ENV_FILE="${ENV_FILE:-/home/xisun/setup_env.sh}"
# Evaluator model. Gateway-valid names: claude-opus-4.8, claude-haiku-4-5
MODEL="${MODEL:-claude-opus-4.8}"

# --- args -------------------------------------------------------------------
if [[ $# -lt 1 ]]; then
  echo "usage: $0 <job-or-trial-path> [extra harbor analyze args...]" >&2
  exit 1
fi
TARGET="$1"; shift
if [[ ! -e "$TARGET" ]]; then
  echo "error: path not found: $TARGET" >&2
  exit 1
fi

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

# The header harbor does not forward on its own. SECURITY: export it as a host
# env var and pass the TEMPLATE (not the value) so harbor stores '${...}' in the
# analysis job config and resolves the real secret from the host env at run time
# — the key never lands in any persisted artifact. See run.sh for the full
# rationale (harbor only name-redacts KEY/SECRET/TOKEN/... vars).
export ANTHROPIC_CUSTOM_HEADERS="Ocp-Apim-Subscription-Key: ${AMD_LLM_GATEWAY_KEY}, user: ${NTID}"
export ANTHROPIC_BASE_URL

# --- run --------------------------------------------------------------------
exec harbor analyze "$TARGET" \
  -a claude-code \
  -m "$MODEL" \
  --ae 'ANTHROPIC_CUSTOM_HEADERS=${ANTHROPIC_CUSTOM_HEADERS}' \
  --ae 'ANTHROPIC_BASE_URL=${ANTHROPIC_BASE_URL}' \
  "$@"
