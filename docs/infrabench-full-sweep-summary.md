# InfraBench Full Sweep Summary

Source: `/sgl-workspace/InfraBench/docs/infra-bench-test-results.md`, cross-checked against final `infra-bench/jobs/*/result.json` files. Smoke, invalid, interrupted, recovery-only, rerun-only, and stopped attempts are excluded. Rows are final completed full sweeps with `20/20` completed trials; times are shown in UTC+8 to match the Harbor UI screenshot.

| Job Name | Agent | Provider | Model | Result | Passed | Environment | Started (UTC+8) | Duration | Trials | Errors | Input Tokens | Output Tokens | Cached Tokens | Cost |
|---|---|---|---|---:|---:|---|---|---:|---:|---:|---:|---:|---:|---:|
| `opencode-mimo-v2.5-pro-onprem` | opencode | onprem | MiMo-V2.5-Pro | 0.40 | 8/20 | docker | 7/21/26, 8:55 PM | 2h 47m | 20/20 | 5 | 10,921,157 | 343,493 | 0 | $11.95 |
| `opencode-mimo-v2-flash-onprem` | opencode | onprem | MiMo-V2-Flash | 0.15 | 3/20 | docker | 7/20/26, 11:28 AM | 2h 15m | 20/20 | 4 | 155,754,490 | 253,215 | 0 | $15.65 |
| `opencode-qwen3.5-397b-a17b-fp8-onprem` | opencode | onprem | Qwen3.5-397B-A17B-FP8 | 0.45 | 9/20 | docker | 7/20/26, 10:07 AM | 50m 57s | 20/20 | 4 | 36,833,348 | 372,072 | 0 | $23.44 |
| `opencode-qwopus3.6-35b-a3b-coder-onprem` | opencode | onprem | Qwopus3.6-35B-A3B-Coder | 0.20 | 4/20 | docker | 7/20/26, 7:01 AM | 2h 35m | 20/20 | 9 | 19,727,018 | 379,202 | 0 | $5.50 |
| `opencode-qwopus3.6-27b-coder-onprem` | opencode | onprem | Qwopus3.6-27B-Coder | 0.40 | 8/20 | docker | 7/20/26, 5:44 AM | 5h 53m | 20/20 | 5 | 23,224,279 | 389,258 | 0 | $3.68 |
| `opencode-kimi-k2.7-code-onprem` | opencode | onprem | Kimi-K2.7-Code | 0.90 | 18/20 | docker | 7/19/26, 6:58 PM | 3h 30m | 20/20 | 6 | 97,838,806 | 917,800 | 0 | $96.62 |
| `opencode-minimax-m3-onprem` | opencode | onprem | MiniMax-M3 | 0.60 | 12/20 | docker | 7/19/26, 4:50 PM | 1h 30m | 20/20 | 6 | 96,050,278 | 792,561 | 0 | $59.53 |
| `opencode-glm-5.2-fp8-onprem` | opencode | onprem | GLM-5.2-FP8 | 0.75 | 15/20 | docker | 7/19/26, 1:14 PM | 2h 55m | 20/20 | 5 | 60,405,209 | 869,947 | 0 | $88.40 |
| `codex-gpt-5.6-terra` | codex | openai | gpt-5.6-terra | 0.90 | 18/20 | docker | 7/19/26, 9:14 AM | 39m 28s | 20/20 | 0 | 27,675,788 | 224,049 | 26,089,216 | $13.85 |
| `claude-opus-4.8` | claude-code | anthropic | claude-opus-4.8 | 0.80 | 16/20 | docker | 7/19/26, 5:38 AM | 1h 54m | 20/20 | 4 | 25,431,301 | 364,020 | 23,713,499 | $69.78 |
| `opencode-gemma-4-31b` | opencode | amd | Gemma-4-31B | 0.05 | 1/20 | docker | 7/19/26, 2:54 AM | 2h 26m | 20/20 | 5 | 1,995,141 | 326,498 | 0 | $0.41 |
| `opencode-gemini-3.5-flash` | opencode | amd | gemini-3.5-flash | 0.70 | 14/20 | docker | 7/19/26, 1:48 AM | 1h 5m | 20/20 | 5 | 114,419,304 | 209,168 | 0 | $173.51 |
| `opencode-qwen3.6-35b-a3b` | opencode | amd | Qwen3.6-35B-A3B | 0.10 | 2/20 | docker | 7/18/26, 9:59 PM | 3h 48m | 20/20 | 13 | 5,886,719 | 137,205 | 0 | $1.68 |
| `opencode-kimi-k2.6` | opencode | amd | Kimi-K2.6 | 0.55 | 11/20 | docker | 7/18/26, 8:49 PM | 1h 9m | 20/20 | 4 | 23,796,031 | 1,028,070 | 16,452,352 | $13.72 |
| `opencode-deepseek-v4-flash` | opencode | amd | DeepSeek-V4-Flash | 0.45 | 9/20 | docker | 7/18/26, 6:05 PM | 2h 23m | 20/20 | 6 | 31,653,073 | 322,104 | 21,452,800 | $1.58 |
| `opencode-minimax-m2.7` | opencode | amd | MiniMax-M2.7 | 0.20 | 4/20 | docker | 7/18/26, 6:46 AM | 1h 9m | 20/20 | 7 | 5,145,380 | 264,587 | 0 | $1.86 |
| `codex-gpt-5.5` | codex | openai | gpt-5.5 | 0.85 | 17/20 | docker | 7/18/26, 3:36 AM | 59m 53s | 20/20 | 0 | 38,400,299 | 290,826 | 35,125,888 | $42.66 |
| `claude-sonnet-5` | claude-code | anthropic | Claude-Sonnet-5 | 0.75 | 15/20 | docker | 7/18/26, 3:26 AM | 1h 42m | 20/20 | 6 | 55,206,726 | 996,213 | 49,576,814 | $26.45 |
| `codex-gpt-5.6-luna` | codex | openai | gpt-5.6-luna | 0.90 | 18/20 | docker | 7/18/26, 1:53 AM | 1h 40m | 20/20 | 1 | 80,248,659 | 300,333 | 77,657,600 | $12.16 |
| `codex-gpt-5.6-sol` | codex | openai | gpt-5.6-sol | 1.00 | 20/20 | docker | 7/18/26, 12:10 AM | 1h 31m | 20/20 | 0 | 52,413,369 | 265,825 | 48,279,808 | $52.78 |
| `claude-haiku-4.5` | claude-code | anthropic | claude-haiku-4.5 | 0.55 | 11/20 | docker | 7/17/26, 8:43 PM | 1h 25m | 20/20 | 1 | 43,677,896 | 308,081 | 38,885,426 | $51.78 |
| `claude-opus-4.6` | claude-code | anthropic | claude-opus-4.6 | 0.80 | 16/20 | docker | 7/17/26, 6:45 PM | 1h 17m | 20/20 | 4 | 30,987,889 | 279,899 | 29,215,353 | $86.81 |

Total included full sweeps: 22
