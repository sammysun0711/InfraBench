#!/usr/bin/env bash
#
# Analyze Terminal-Bench trial trajectories through the AMD internal LLM
# gateway. Defaults to the claude-code evaluator; set AGENT=codex to use the
# same AMD Codex adapter as run_codex.sh.
#
# Like `harbor run`, `harbor analyze` spawns an agent in a container but does
# not forward every host-side auth setting automatically, so this wrapper injects
# the gateway credentials explicitly with `--ae`.
#
# Usage:
#   ./analyze.sh jobs/2026-07-05__07-09-50/          # analyze a whole job
#   ./analyze.sh jobs/2026-07-05__07-09-50/regex-chess__DhXyi8C   # one trial
#   ./analyze.sh jobs/<job> --failing                # only failing trials
#   ./analyze.sh jobs/<job> -r my-rubric.toml        # custom rubric
#   AGENT=codex MODEL=gpt-5.5 ./analyze.sh jobs/<job> --failing
#   Any extra args are passed straight through to `harbor analyze`.
set -euo pipefail

# --- config -----------------------------------------------------------------
ENV_FILE="${ENV_FILE:-${HOME:?HOME not set}/setup_env.sh}"
# Evaluator agent. Supported values: claude-code (default), codex.
AGENT="${AGENT:-claude-code}"
# Evaluator model. Agent-specific defaults are selected below when MODEL is unset.
MODEL="${MODEL:-}"

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
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_ARGS=()

case "$AGENT" in
  claude|claude-code)
    MODEL="${MODEL:-claude-opus-4.8}"
    if [[ ! -f "$ENV_FILE" ]]; then
      echo "error: env file not found: $ENV_FILE" >&2
      exit 1
    fi
    : "${AMD_LLM_GATEWAY_KEY:?AMD_LLM_GATEWAY_KEY not set (check $ENV_FILE)}"
    : "${NTID:?NTID not set (check $ENV_FILE)}"
    : "${ANTHROPIC_BASE_URL:?ANTHROPIC_BASE_URL not set (check $ENV_FILE)}"

    # The header harbor does not forward on its own. SECURITY: export it as a
    # host env var and pass the TEMPLATE (not the value) so harbor stores
    # '${...}' in the analysis job config and resolves the real secret from the
    # host env at run time. The key never lands in any persisted artifact. See
    # run_claude_code.sh for the full rationale.
    export ANTHROPIC_CUSTOM_HEADERS="Ocp-Apim-Subscription-Key: ${AMD_LLM_GATEWAY_KEY}, user: ${NTID}"
    export ANTHROPIC_BASE_URL

    AGENT_ARGS=(
      -a claude-code
      -m "$MODEL"
      --ae 'ANTHROPIC_CUSTOM_HEADERS=${ANTHROPIC_CUSTOM_HEADERS}'
      --ae 'ANTHROPIC_BASE_URL=${ANTHROPIC_BASE_URL}'
    )
    ;;

  codex|amd-codex)
    MODEL="${MODEL:-gpt-5.5}"
    GATEWAY_BASE_URL="${AMD_CODEX_BASE_URL:-https://llm-api.amd.com/Unified/v1}"

    # Prefix the model for Harbor metadata, matching run_codex.sh. Harbor's
    # Codex agent strips the provider when invoking the CLI; the custom provider
    # block routes the request through AMD.
    PROVIDER_ID="${CODEX_PROVIDER:-openai}"
    case "$MODEL" in */*) : ;; *) MODEL="${PROVIDER_ID}/${MODEL}" ;; esac

    AMD_GATEWAY_SUBKEY="${AMD_GATEWAY_SUBKEY:-${AMD_CODEX_SUBKEY:-}}"
    if [[ -z "$AMD_GATEWAY_SUBKEY" && -f "$HOME/.codex/config.toml" ]]; then
      AMD_GATEWAY_SUBKEY="$(sed -nE 's/.*"Ocp-Apim-Subscription-Key"[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' "$HOME/.codex/config.toml" | head -1)"
    fi
    AMD_GATEWAY_NTID="${AMD_GATEWAY_NTID:-${NTID:-}}"
    : "${AMD_GATEWAY_SUBKEY:?could not resolve gateway subkey (set AMD_GATEWAY_SUBKEY or configure ~/.codex/config.toml)}"
    : "${AMD_GATEWAY_NTID:?AMD_GATEWAY_NTID/NTID not set (check $ENV_FILE)}"

    export AMD_GATEWAY_SUBKEY
    export AMD_GATEWAY_NTID
    export OPENAI_BASE_URL="$GATEWAY_BASE_URL"
    export PYTHONPATH="${SCRIPT_DIR}:${PYTHONPATH:-}"

    AGENT_IMPORT="${CODEX_AGENT_IMPORT:-agents.amd_codex:AmdCodex}"
    AGENT_ARGS=(
      -a "$AGENT_IMPORT"
      -m "$MODEL"
      --ae 'AMD_GATEWAY_SUBKEY=${AMD_GATEWAY_SUBKEY}'
      --ae 'AMD_GATEWAY_NTID=${AMD_GATEWAY_NTID}'
      --ae 'OPENAI_BASE_URL=${OPENAI_BASE_URL}'
    )
    ;;

  *)
    echo "error: unsupported AGENT=$AGENT (supported: claude-code, codex)" >&2
    exit 1
    ;;
esac

# --- run --------------------------------------------------------------------
exec harbor analyze "$TARGET" "${AGENT_ARGS[@]}" "$@"
