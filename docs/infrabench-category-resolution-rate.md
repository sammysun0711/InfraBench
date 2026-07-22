# InfraBench Category Task Resolution Rate

Source data: final full-sweep `infra-bench/jobs/*/result.json` files. Smoke, invalid, interrupted, recovery-only, rerun-only, stopped/cache0, and analyzer jobs are excluded. The `smoke-test` category (`hello-rocm`) is excluded from both category columns and overall rates.

Task categories are parsed from `README.md`. `compiler-optimization` and `algorithm-implementation` have been merged into `algorithm` in the README.

## Category Definitions

| Category | Tasks | Count |
|---|---|---:|
| `model-deployment` | `gemma4-sglang-serving-opt`, `llm-fp8-quantize` | 2 |
| `profiling-analysis` | `hotspot-analysis-torch-profiler`, `mem-bandwidth-bench`, `gluon-a8w8-mfma-att`, `sglang-sync-stall` | 4 |
| `kernel-tuning` | `gemma4-gemm-tuning`, `triton-matmul-tuning`, `dwconv3d-occupancy` | 3 |
| `kernel-implementation` | `engram-triton-kernel`, `flydsl-cdna4-preshuffle-gemm`, `paged-attention-hd256`, `gemm-fp8-ptpc-quant`, `qr-rmsnorm-fusion` | 5 |
| `algorithm` | `llvm-simple-constant-propagation`, `cute-layout-composition` | 2 |
| `debug-triage` | `pointnet2-hipify`, `vllm-aiter-debug`, `sglang-mmmu-ipc-crash` | 3 |

## Full Sweep Category Rates

| Job | Model (Agent) | Overall excl. smoke | `model-deployment` | `profiling-analysis` | `kernel-tuning` | `kernel-implementation` | `algorithm` | `debug-triage` |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| `codex-gpt-5.6-sol` | gpt-5.6-sol (codex) | 19/19 (100%) | 2/2 (100%) | 4/4 (100%) | 3/3 (100%) | 5/5 (100%) | 2/2 (100%) | 3/3 (100%) |
| `codex-gpt-5.6-luna` | gpt-5.6-luna (codex) | 17/19 (89%) | 1/2 (50%) | 4/4 (100%) | 3/3 (100%) | 4/5 (80%) | 2/2 (100%) | 3/3 (100%) |
| `codex-gpt-5.6-terra` | gpt-5.6-terra (codex) | 17/19 (89%) | 1/2 (50%) | 4/4 (100%) | 3/3 (100%) | 4/5 (80%) | 2/2 (100%) | 3/3 (100%) |
| `opencode-kimi-k2.7-code-onprem` | Kimi-K2.7-Code (opencode) | 17/19 (89%) | 2/2 (100%) | 4/4 (100%) | 2/3 (67%) | 4/5 (80%) | 2/2 (100%) | 3/3 (100%) |
| `codex-gpt-5.5` | gpt-5.5 (codex) | 16/19 (84%) | 2/2 (100%) | 4/4 (100%) | 3/3 (100%) | 3/5 (60%) | 1/2 (50%) | 3/3 (100%) |
| `claude-opus-4.6` | claude-opus-4.6 (claude-code) | 15/19 (79%) | 1/2 (50%) | 4/4 (100%) | 2/3 (67%) | 4/5 (80%) | 1/2 (50%) | 3/3 (100%) |
| `claude-opus-4.8` | claude-opus-4.8 (claude-code) | 15/19 (79%) | 1/2 (50%) | 4/4 (100%) | 2/3 (67%) | 4/5 (80%) | 1/2 (50%) | 3/3 (100%) |
| `claude-sonnet-5` | Claude-Sonnet-5 (claude-code) | 14/19 (74%) | 0/2 (0%) | 4/4 (100%) | 2/3 (67%) | 3/5 (60%) | 2/2 (100%) | 3/3 (100%) |
| `opencode-glm-5.2-fp8-onprem` | GLM-5.2-FP8 (opencode) | 14/19 (74%) | 0/2 (0%) | 4/4 (100%) | 3/3 (100%) | 3/5 (60%) | 1/2 (50%) | 3/3 (100%) |
| `opencode-gemini-3.5-flash` | gemini-3.5-flash (opencode) | 13/19 (68%) | 1/2 (50%) | 3/4 (75%) | 3/3 (100%) | 5/5 (100%) | 0/2 (0%) | 1/3 (33%) |
| `opencode-minimax-m3-onprem` | MiniMax-M3 (opencode) | 11/19 (58%) | 1/2 (50%) | 2/4 (50%) | 2/3 (67%) | 2/5 (40%) | 2/2 (100%) | 2/3 (67%) |
| `claude-haiku-4.5` | claude-haiku-4.5 (claude-code) | 10/19 (53%) | 0/2 (0%) | 3/4 (75%) | 1/3 (33%) | 4/5 (80%) | 1/2 (50%) | 1/3 (33%) |
| `opencode-kimi-k2.6` | Kimi-K2.6 (opencode) | 10/19 (53%) | 1/2 (50%) | 3/4 (75%) | 1/3 (33%) | 2/5 (40%) | 1/2 (50%) | 2/3 (67%) |
| `opencode-deepseek-v4-flash` | DeepSeek-V4-Flash (opencode) | 8/19 (42%) | 0/2 (0%) | 2/4 (50%) | 1/3 (33%) | 2/5 (40%) | 1/2 (50%) | 2/3 (67%) |
| `opencode-qwen3.5-397b-a17b-fp8-onprem` | Qwen3.5-397B-A17B-FP8 (opencode) | 8/19 (42%) | 0/2 (0%) | 2/4 (50%) | 1/3 (33%) | 2/5 (40%) | 1/2 (50%) | 2/3 (67%) |
| `opencode-mimo-v2.5-pro-onprem` | MiMo-V2.5-Pro (opencode) | 7/19 (37%) | 0/2 (0%) | 3/4 (75%) | 0/3 (0%) | 0/5 (0%) | 1/2 (50%) | 3/3 (100%) |
| `opencode-qwopus3.6-27b-coder-onprem` | Qwopus3.6-27B-Coder (opencode) | 7/19 (37%) | 0/2 (0%) | 2/4 (50%) | 1/3 (33%) | 0/5 (0%) | 1/2 (50%) | 3/3 (100%) |
| `opencode-minimax-m2.7` | MiniMax-M2.7 (opencode) | 3/19 (16%) | 0/2 (0%) | 2/4 (50%) | 1/3 (33%) | 0/5 (0%) | 0/2 (0%) | 0/3 (0%) |
| `opencode-qwopus3.6-35b-a3b-coder-onprem` | Qwopus3.6-35B-A3B-Coder (opencode) | 3/19 (16%) | 0/2 (0%) | 0/4 (0%) | 0/3 (0%) | 0/5 (0%) | 1/2 (50%) | 2/3 (67%) |
| `opencode-mimo-v2-flash-onprem` | MiMo-V2-Flash (opencode) | 2/19 (11%) | 0/2 (0%) | 1/4 (25%) | 1/3 (33%) | 0/5 (0%) | 0/2 (0%) | 0/3 (0%) |
| `opencode-qwen3.6-35b-a3b` | Qwen3.6-35B-A3B (opencode) | 1/19 (5%) | 0/2 (0%) | 0/4 (0%) | 0/3 (0%) | 0/5 (0%) | 0/2 (0%) | 1/3 (33%) |
| `opencode-gemma-4-31b` | Gemma-4-31B (opencode) | 0/19 (0%) | 0/2 (0%) | 0/4 (0%) | 0/3 (0%) | 0/5 (0%) | 0/2 (0%) | 0/3 (0%) |

Total included full sweeps: 22
