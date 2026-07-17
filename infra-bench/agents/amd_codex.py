"""Custom Codex agent for the AMD LLM gateway (Unified endpoint).

harbor's stock `codex` agent authenticates with a standard OpenAI Bearer key
(`OPENAI_API_KEY`). The AMD gateway at https://llm-api.amd.com/Unified/v1 rejects
Bearer auth — it requires a custom `Ocp-Apim-Subscription-Key` HTTP header plus an
`ntid`, delivered through a codex custom `[model_providers.*]` block. Harbor's
codex agent has no built-in way to emit that block, so this subclass injects it.

We hook `_build_register_mcp_servers_command()` — the one seam harbor's `run()`
appends to `$CODEX_HOME/config.toml` right after writing `openai_base_url`. We
emit an `[model_providers.amd]` provider (name + base_url + the required
`http_headers`) and set the top-level `model_provider = "amd"` so `codex exec
--model <name>` routes through it.

Secrets are referenced as shell env templates (`${AMD_GATEWAY_SUBKEY}`,
`${AMD_GATEWAY_NTID}`) that resolve inside the container at setup time, so the
literal subscription key never appears in the command string harbor builds.

Usage (see run_codex.sh):
    harbor run -a infra-bench.agents.amd_codex:AmdCodex -m gpt-5.5 \
      --ae 'AMD_GATEWAY_SUBKEY=${AMD_GATEWAY_SUBKEY}' \
      --ae 'AMD_GATEWAY_NTID=${AMD_GATEWAY_NTID}' \
      --ae 'OPENAI_BASE_URL=https://llm-api.amd.com/Unified/v1' \
      -p tasks/hello-rocm
"""
try:  # py3.12+
    from typing import override
except ImportError:  # py3.10/3.11
    def override(func):
        return func

from harbor.agents.installed.codex import Codex


class AmdCodex(Codex):
    """Codex wired to the AMD Unified gateway via a custom provider block."""

    # codex config: top-level provider id + the provider table key.
    _PROVIDER_ID = "amd"

    @override
    def _build_register_mcp_servers_command(self) -> str | None:
        # Preserve harbor's MCP-server config (may be None).
        base = super()._build_register_mcp_servers_command()

        base_url = self._get_env("OPENAI_BASE_URL") or "https://llm-api.amd.com/Unified/v1"

        # The subkey/ntid are read from container env at write time via ${...},
        # so the literal secret is not embedded in this command string. The
        # heredoc is unquoted (TOML, not 'TOML') so the shell expands them.
        provider_block = (
            '\ncat >>"$CODEX_HOME/config.toml" <<TOML\n'
            f'model_provider = "{self._PROVIDER_ID}"\n'
            f"[model_providers.{self._PROVIDER_ID}]\n"
            'name = "AMD LLM Gateway"\n'
            f'base_url = "{base_url}"\n'
            'api_key = ""\n'
            f"[model_providers.{self._PROVIDER_ID}.http_headers]\n"
            '"Ocp-Apim-Subscription-Key" = "${AMD_GATEWAY_SUBKEY}"\n'
            '"ntid" = "${AMD_GATEWAY_NTID}"\n'
            "TOML"
        )

        return f"{base}\n{provider_block}" if base else provider_block
