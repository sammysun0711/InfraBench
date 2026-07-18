# InfraBench Test Results

Run date: 2026-07-17

Source plan: `docs/infra-bench-test-plan.md`

Workspace: `/home/xisun/InfraBench`

## Prerequisite Check

Commands were run from `/home/xisun/InfraBench/infra-bench`.

| Check | Result |
|---|---|
| `harbor --version` | `0.17.1` |
| `docker --version` | `Docker version 29.6.0, build fb59821` |
| `docker compose version` | `Docker Compose version v5.1.4` |
| ROCm devices | `/dev/kfd` present, `/dev/dri` present |
| GPU inventory | `rocm-smi --showid` reports 8 AMD Instinct MI350X GPUs |
| Gateway env | `AMD_LLM_GATEWAY_KEY`, `NTID`, `ANTHROPIC_BASE_URL` set |
| Codex/OpenCode gateway key | resolved from `~/.codex/config.toml` |

## Smoke Tests

All three smoke tests passed on `hello-rocm`.

| Agent | Model | Job | Reward | Cost USD | Run log | Trajectory |
|---|---|---:|---:|---:|---|---|
| claude-code | `claude-opus-4.6` | `smoke-claude-hello` | 1/1 | 1.222706 | `infra-bench/jobs/smoke-claude-hello/run.log` | `infra-bench/jobs/smoke-claude-hello/hello-rocm__LsHUNXp/agent/trajectory.json` |
| codex | `gpt-5.5` | `smoke-codex-hello` | 1/1 | 0.078585 | `infra-bench/jobs/smoke-codex-hello/run.log` | `infra-bench/jobs/smoke-codex-hello/hello-rocm__pPxvKzz/agent/trajectory.json` |
| opencode | `DeepSeek-V4-Flash` | `smoke-opencode-hello` | 1/1 | 0.003342 | `infra-bench/jobs/smoke-opencode-hello/run.log` | `infra-bench/jobs/smoke-opencode-hello/hello-rocm__PBqwCdB/agent/trajectory.json` |

### Smoke Command Logs

#### `smoke-claude-hello`

Command:

```bash
JOB_NAME=smoke-claude-hello MODEL=claude-opus-4.6 ./run_claude_code.sh -i hello-rocm
```

Log excerpt:

```text
infra-bench * claude-code * claude-opus-4.6
Trials: 1
Exceptions: 0
Mean: 1.000
Total runtime: 45s
Results written to /home/xisun/InfraBench/infra-bench/jobs/smoke-claude-hello/result.json
[run_claude_code.sh] rewards:
  hello-rocm__LsHUNXp: 1
[run_claude_code.sh] 1/1 passed
```

Verifier log:

- `infra-bench/jobs/smoke-claude-hello/hello-rocm__LsHUNXp/verifier/test-stdout.txt`

#### `smoke-codex-hello`

Command:

```bash
JOB_NAME=smoke-codex-hello MODEL=gpt-5.5 ./run_codex.sh -i hello-rocm
```

Log excerpt:

```text
infra-bench * codex * gpt-5.5
Trials: 1
Exceptions: 0
Mean: 1.000
Total runtime: 1m 50s
Results written to /home/xisun/InfraBench/infra-bench/jobs/smoke-codex-hello/result.json
[run_codex.sh] rewards:
  hello-rocm__pPxvKzz: 1
[run_codex.sh] 1/1 passed
```

Verifier log:

- `infra-bench/jobs/smoke-codex-hello/hello-rocm__pPxvKzz/verifier/test-stdout.txt`

#### `smoke-opencode-hello`

Command:

```bash
JOB_NAME=smoke-opencode-hello MODEL=DeepSeek-V4-Flash AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' ./run_open_code.sh -i hello-rocm
```

Log excerpt:

```text
infra-bench * opencode * DeepSeek-V4-Flash
Trials: 1
Exceptions: 0
Mean: 1.000
Total runtime: 47s
Results written to /home/xisun/InfraBench/infra-bench/jobs/smoke-opencode-hello/result.json
[run_open_code.sh] rewards:
  hello-rocm__PBqwCdB: 1
[run_open_code.sh] 1/1 passed
```

Verifier log:

- `infra-bench/jobs/smoke-opencode-hello/hello-rocm__PBqwCdB/verifier/test-stdout.txt`

## Full Sweeps

### `claude-opus-4.6`

Primary command:

```bash
JOB_NAME=claude-opus-4.6 MODEL=claude-opus-4.6 INFRA_PARALLEL=6 INFRABENCH_GPU_COUNT=8 ./run_claude_code.sh
```

The original primary run was interrupted before Harbor finalized the job
metadata. At interruption time it had 17 completed trials, 2 errored trials, and
3 stale running/incomplete trials. I ran a recovery subset for the
interrupted/missing tasks:

```bash
JOB_NAME=claude-opus-4.6-recovery MODEL=claude-opus-4.6 INFRA_PARALLEL=5 INFRABENCH_GPU_COUNT=8 ./run_claude_code.sh \
  -i cute-layout-composition \
  -i llm-fp8-quantize \
  -i gemma4-sglang-serving-opt \
  -i vllm-aiter-debug \
  -i sglang-sync-stall
```

Recovery log excerpt:

```text
infra-bench * claude-code * claude-opus-4.6
Trials: 5
Exceptions: 4
Mean: 0.600
Total runtime: 36m 16s
Results written to /home/xisun/InfraBench/infra-bench/jobs/claude-opus-4.6-recovery/result.json
[run_claude_code.sh] rewards:
  cute-layout-composition__dChnYM9: 0
  gemma4-sglang-serving-opt__SJG5iQF: 0
  llm-fp8-quantize__uFwNZ9F: 1
  sglang-sync-stall__pAGZKCU: 1
  vllm-aiter-debug__Sp6FQAs: 1
[run_claude_code.sh] 3/5 passed
```

Combined scoreboard for this model, using recovery results for the interrupted
tasks: **16/20 passed**.

For upload-readiness, `infra-bench/jobs/claude-opus-4.6` has been rebuilt as a
synthetic merged 20-task job containing the 15 valid primary trials plus the 5
recovery trials listed below. The original interrupted primary directory is
preserved at `infra-bench/jobs/claude-opus-4.6-unmerged-20260718-083004`, and
the merged job includes `infra-bench/jobs/claude-opus-4.6/merge_manifest.json`.
The merged `result.json` has `finished_at: 2026-07-17T12:03:32.751401`,
`completed: 20`, `running: 0`, `pending: 0`, `errored: 4`, and
`cost_usd: 86.807045`.

| Task | Reward | Source job | Trial | Trajectory |
|---|---:|---|---|---|
| `cute-layout-composition` | 0 | `claude-opus-4.6` merged from recovery | `cute-layout-composition__dChnYM9` | `infra-bench/jobs/claude-opus-4.6/cute-layout-composition__dChnYM9/agent/trajectory.json` |
| `dwconv3d-occupancy` | 1 | `claude-opus-4.6` | `dwconv3d-occupancy__aQrZmfs` | `infra-bench/jobs/claude-opus-4.6/dwconv3d-occupancy__aQrZmfs/agent/trajectory.json` |
| `engram-triton-kernel` | 1 | `claude-opus-4.6` | `engram-triton-kernel__QiWbock` | `infra-bench/jobs/claude-opus-4.6/engram-triton-kernel__QiWbock/agent/trajectory.json` |
| `flydsl-cdna4-preshuffle-gemm` | 0 | `claude-opus-4.6` | `flydsl-cdna4-preshuffle-gemm__gWnCL5y` | `infra-bench/jobs/claude-opus-4.6/flydsl-cdna4-preshuffle-gemm__gWnCL5y/agent/trajectory.json` |
| `gemm-fp8-ptpc-quant` | 1 | `claude-opus-4.6` | `gemm-fp8-ptpc-quant__635S5mT` | `infra-bench/jobs/claude-opus-4.6/gemm-fp8-ptpc-quant__635S5mT/agent/trajectory.json` |
| `gemma4-gemm-tuning` | 0 | `claude-opus-4.6` | `gemma4-gemm-tuning__CP2xpvw` | `infra-bench/jobs/claude-opus-4.6/gemma4-gemm-tuning__CP2xpvw/agent/trajectory.json` |
| `gemma4-sglang-serving-opt` | 0 | `claude-opus-4.6` merged from recovery | `gemma4-sglang-serving-opt__SJG5iQF` | `infra-bench/jobs/claude-opus-4.6/gemma4-sglang-serving-opt__SJG5iQF/agent/trajectory.json` |
| `gluon-a8w8-mfma-att` | 1 | `claude-opus-4.6` | `gluon-a8w8-mfma-att__eBPZjuF` | `infra-bench/jobs/claude-opus-4.6/gluon-a8w8-mfma-att__eBPZjuF/agent/trajectory.json` |
| `hello-rocm` | 1 | `claude-opus-4.6` | `hello-rocm__8jjDrhb` | `infra-bench/jobs/claude-opus-4.6/hello-rocm__8jjDrhb/agent/trajectory.json` |
| `hotspot-analysis-torch-profiler` | 1 | `claude-opus-4.6` | `hotspot-analysis-torch-profiler__JYML2tu` | `infra-bench/jobs/claude-opus-4.6/hotspot-analysis-torch-profiler__JYML2tu/agent/trajectory.json` |
| `llm-fp8-quantize` | 1 | `claude-opus-4.6` merged from recovery | `llm-fp8-quantize__uFwNZ9F` | `infra-bench/jobs/claude-opus-4.6/llm-fp8-quantize__uFwNZ9F/agent/trajectory.json` |
| `llvm-simple-constant-propagation` | 1 | `claude-opus-4.6` | `llvm-simple-constant-propagation__aMBxXyr` | `infra-bench/jobs/claude-opus-4.6/llvm-simple-constant-propagation__aMBxXyr/agent/trajectory.json` |
| `mem-bandwidth-bench` | 1 | `claude-opus-4.6` | `mem-bandwidth-bench__KuxP9A2` | `infra-bench/jobs/claude-opus-4.6/mem-bandwidth-bench__KuxP9A2/agent/trajectory.json` |
| `paged-attention-hd256` | 1 | `claude-opus-4.6` | `paged-attention-hd256__BZ3AHYE` | `infra-bench/jobs/claude-opus-4.6/paged-attention-hd256__BZ3AHYE/agent/trajectory.json` |
| `pointnet2-hipify` | 1 | `claude-opus-4.6` | `pointnet2-hipify__U6ZyYJX` | `infra-bench/jobs/claude-opus-4.6/pointnet2-hipify__U6ZyYJX/agent/trajectory.json` |
| `qr-rmsnorm-fusion` | 1 | `claude-opus-4.6` | `qr-rmsnorm-fusion__hhe8qXD` | `infra-bench/jobs/claude-opus-4.6/qr-rmsnorm-fusion__hhe8qXD/agent/trajectory.json` |
| `sglang-mmmu-ipc-crash` | 1 | `claude-opus-4.6` | `sglang-mmmu-ipc-crash__iFmefB2` | `infra-bench/jobs/claude-opus-4.6/sglang-mmmu-ipc-crash__iFmefB2/agent/trajectory.json` |
| `sglang-sync-stall` | 1 | `claude-opus-4.6` merged from recovery | `sglang-sync-stall__pAGZKCU` | `infra-bench/jobs/claude-opus-4.6/sglang-sync-stall__pAGZKCU/agent/trajectory.json` |
| `triton-matmul-tuning` | 1 | `claude-opus-4.6` | `triton-matmul-tuning__WztGK9x` | `infra-bench/jobs/claude-opus-4.6/triton-matmul-tuning__WztGK9x/agent/trajectory.json` |
| `vllm-aiter-debug` | 1 | `claude-opus-4.6` merged from recovery | `vllm-aiter-debug__Sp6FQAs` | `infra-bench/jobs/claude-opus-4.6/vllm-aiter-debug__Sp6FQAs/agent/trajectory.json` |

Cost observed so far for this model: primary job `64.325270` USD plus recovery
job `22.481774` USD, total `86.807045` USD.

Notable failures:

- `cute-layout-composition`: recovery trial ended with `AgentTimeoutError`.
- `flydsl-cdna4-preshuffle-gemm`: verifier reward 0, no exception.
- `gemma4-gemm-tuning`: verifier reward 0, no exception.
- `gemma4-sglang-serving-opt`: recovery trial ended with `NonZeroAgentExitCodeError`
  and reward 0.

### Superseded Haiku Notes

This subsection preserves notes from the earlier Haiku attempts. The
authoritative combined `claude-haiku-4.5` scoreboard is in the following model
section.

Initial full command:

```bash
JOB_NAME=claude-haiku-4.5 MODEL=claude-haiku-4.5 INFRA_PARALLEL=6 INFRABENCH_GPU_COUNT=8 ./run_claude_code.sh
```

That first attempt exited abnormally with code 143 before Harbor finalized the
job. A tmux rerun then failed immediately because Docker had exhausted its
predefined network address pools. I pruned unused Docker networks and ran a clean
full rerun:

```bash
JOB_NAME=claude-haiku-4.5-rerun2 MODEL=claude-haiku-4.5 INFRA_PARALLEL=6 INFRABENCH_GPU_COUNT=8 ./run_claude_code.sh
```

Full rerun excerpt:

```text
infra-bench * claude-code * claude-haiku-4.5
Trials: 16
Exceptions: 5
Mean: 0.400
Total runtime: 28m 25s
Results written to /home/xisun/InfraBench/infra-bench/jobs/claude-haiku-4.5-rerun2/result.json
[run_claude_code.sh] 8/16 passed
```

Four tasks failed before agent execution because the non-blocking GPU allocator
could not claim a GPU while the suite was oversubscribed. I ran a recovery subset:

```bash
JOB_NAME=claude-haiku-4.5-recovery MODEL=claude-haiku-4.5 ./run_claude_code.sh \
  -i gemm-fp8-ptpc-quant \
  -i flydsl-cdna4-preshuffle-gemm \
  -i llm-fp8-quantize \
  -i pointnet2-hipify
```

Recovery result: 3/4 passed. Those source jobs were later merged into the
upload-ready synthetic job `infra-bench/jobs/claude-haiku-4.5`; the original
interrupted `claude-haiku-4.5` artifact is preserved at
`infra-bench/jobs/claude-haiku-4.5_bk`. See the canonical model section below
for the merged 11/20 scoreboard and trajectory paths.

### `claude-haiku-4.5`

The first haiku job, `claude-haiku-4.5`, was started while the opus recovery job
was still consuming GPUs and produced many Docker environment startup
`RuntimeError`s. I stopped that contaminated run and preserved its directory as
`infra-bench/jobs/claude-haiku-4.5_bk`. A second clean attempt,
`claude-haiku-4.5-clean`, also produced 18 infra exceptions and is not used for
the scoreboard.

Valid candidate command:

```bash
JOB_NAME=claude-haiku-4.5-rerun2 MODEL=claude-haiku-4.5 INFRA_PARALLEL=6 INFRABENCH_GPU_COUNT=8 ./run_claude_code.sh
```

The valid candidate still had four infra-only `RuntimeError` tasks with no
trajectory, so I ran a recovery subset:

```bash
JOB_NAME=claude-haiku-4.5-recovery MODEL=claude-haiku-4.5 INFRA_PARALLEL=4 INFRABENCH_GPU_COUNT=8 ./run_claude_code.sh \
  -i gemm-fp8-ptpc-quant \
  -i flydsl-cdna4-preshuffle-gemm \
  -i llm-fp8-quantize \
  -i pointnet2-hipify
```

Main rerun log excerpt:

```text
infra-bench * claude-code * claude-haiku-4.5
Trials: 16
Exceptions: 5
Mean: 0.400
Total runtime: 28m 25s
Results written to /home/xisun/InfraBench/infra-bench/jobs/claude-haiku-4.5-rerun2/result.json
Reward 1.0: 8
Reward 0.0: 8
```

Recovery result:

```text
infra-bench * claude-code * claude-haiku-4.5
Trials: 4
Exceptions: 0
Reward 1.0: 3
Reward 0.0: 1
Results written to /home/xisun/InfraBench/infra-bench/jobs/claude-haiku-4.5-recovery/result.json
```

For upload-readiness, `infra-bench/jobs/claude-haiku-4.5` has been rebuilt as a
synthetic merged 20-task job containing the 16 selected `claude-haiku-4.5-rerun2`
trials plus the 4 recovery trials. The merged job includes
`infra-bench/jobs/claude-haiku-4.5/merge_manifest.json`; its `result.json` has
`finished_at: 2026-07-17T14:08:36.851286`, `cost_usd: 51.780563`,
20 reward files, and 20 structured agent trajectories.

Merged scoreboard for this model, using recovery results for infra-failed tasks:
**11/20 passed**.

| Task | Reward | Source job | Trial | Trajectory |
|---|---:|---|---|---|
| `cute-layout-composition` | 0 | `claude-haiku-4.5` | `cute-layout-composition__FpNf9io` | `infra-bench/jobs/claude-haiku-4.5/cute-layout-composition__FpNf9io/agent/trajectory.json` |
| `dwconv3d-occupancy` | 1 | `claude-haiku-4.5` | `dwconv3d-occupancy__JWgSwg2` | `infra-bench/jobs/claude-haiku-4.5/dwconv3d-occupancy__JWgSwg2/agent/trajectory.json` |
| `engram-triton-kernel` | 1 | `claude-haiku-4.5` | `engram-triton-kernel__5idzyiu` | `infra-bench/jobs/claude-haiku-4.5/engram-triton-kernel__5idzyiu/agent/trajectory.json` |
| `flydsl-cdna4-preshuffle-gemm` | 1 | `claude-haiku-4.5` merged from recovery | `flydsl-cdna4-preshuffle-gemm__EHgZQX4` | `infra-bench/jobs/claude-haiku-4.5/flydsl-cdna4-preshuffle-gemm__EHgZQX4/agent/trajectory.json` |
| `gemm-fp8-ptpc-quant` | 1 | `claude-haiku-4.5` merged from recovery | `gemm-fp8-ptpc-quant__qKbqTFz` | `infra-bench/jobs/claude-haiku-4.5/gemm-fp8-ptpc-quant__qKbqTFz/agent/trajectory.json` |
| `gemma4-gemm-tuning` | 0 | `claude-haiku-4.5` | `gemma4-gemm-tuning__goVgygT` | `infra-bench/jobs/claude-haiku-4.5/gemma4-gemm-tuning__goVgygT/agent/trajectory.json` |
| `gemma4-sglang-serving-opt` | 0 | `claude-haiku-4.5` | `gemma4-sglang-serving-opt__Kw7vbAW` | `infra-bench/jobs/claude-haiku-4.5/gemma4-sglang-serving-opt__Kw7vbAW/agent/trajectory.json` |
| `gluon-a8w8-mfma-att` | 1 | `claude-haiku-4.5` | `gluon-a8w8-mfma-att__zbZ5epq` | `infra-bench/jobs/claude-haiku-4.5/gluon-a8w8-mfma-att__zbZ5epq/agent/trajectory.json` |
| `hello-rocm` | 1 | `claude-haiku-4.5` | `hello-rocm__4Pmiy29` | `infra-bench/jobs/claude-haiku-4.5/hello-rocm__4Pmiy29/agent/trajectory.json` |
| `hotspot-analysis-torch-profiler` | 1 | `claude-haiku-4.5` | `hotspot-analysis-torch-profiler__8cndycB` | `infra-bench/jobs/claude-haiku-4.5/hotspot-analysis-torch-profiler__8cndycB/agent/trajectory.json` |
| `llm-fp8-quantize` | 0 | `claude-haiku-4.5` merged from recovery | `llm-fp8-quantize__B9het7G` | `infra-bench/jobs/claude-haiku-4.5/llm-fp8-quantize__B9het7G/agent/trajectory.json` |
| `llvm-simple-constant-propagation` | 1 | `claude-haiku-4.5` | `llvm-simple-constant-propagation__MHLWxc6` | `infra-bench/jobs/claude-haiku-4.5/llvm-simple-constant-propagation__MHLWxc6/agent/trajectory.json` |
| `mem-bandwidth-bench` | 1 | `claude-haiku-4.5` | `mem-bandwidth-bench__76Pcd5a` | `infra-bench/jobs/claude-haiku-4.5/mem-bandwidth-bench__76Pcd5a/agent/trajectory.json` |
| `paged-attention-hd256` | 0 | `claude-haiku-4.5` | `paged-attention-hd256__wUvBqS3` | `infra-bench/jobs/claude-haiku-4.5/paged-attention-hd256__wUvBqS3/agent/trajectory.json` |
| `pointnet2-hipify` | 1 | `claude-haiku-4.5` merged from recovery | `pointnet2-hipify__NJoosig` | `infra-bench/jobs/claude-haiku-4.5/pointnet2-hipify__NJoosig/agent/trajectory.json` |
| `qr-rmsnorm-fusion` | 1 | `claude-haiku-4.5` | `qr-rmsnorm-fusion__SeC4TmJ` | `infra-bench/jobs/claude-haiku-4.5/qr-rmsnorm-fusion__SeC4TmJ/agent/trajectory.json` |
| `sglang-mmmu-ipc-crash` | 0 | `claude-haiku-4.5` | `sglang-mmmu-ipc-crash__qDqZJMb` | `infra-bench/jobs/claude-haiku-4.5/sglang-mmmu-ipc-crash__qDqZJMb/agent/trajectory.json` |
| `sglang-sync-stall` | 0 | `claude-haiku-4.5` | `sglang-sync-stall__84bDeQu` | `infra-bench/jobs/claude-haiku-4.5/sglang-sync-stall__84bDeQu/agent/trajectory.json` |
| `triton-matmul-tuning` | 0 | `claude-haiku-4.5` | `triton-matmul-tuning__vUbHZco` | `infra-bench/jobs/claude-haiku-4.5/triton-matmul-tuning__vUbHZco/agent/trajectory.json` |
| `vllm-aiter-debug` | 0 | `claude-haiku-4.5` | `vllm-aiter-debug__MMtsmXB` | `infra-bench/jobs/claude-haiku-4.5/vllm-aiter-debug__MMtsmXB/agent/trajectory.json` |

Cost observed for the usable haiku result: main rerun `30.919039` USD plus
recovery `20.861524` USD, total `51.780563` USD.

Post-merge validation:

```text
finished_at 2026-07-17T14:08:36.851286
counts 20 0 0 1 51.780563
reward_counts {'1.0': 11, '0.0': 9}
exception_counts {'NonZeroAgentExitCodeError': 1}
files 20 20 20 20
```

`./infra-bench/analyze.sh infra-bench/jobs/claude-haiku-4.5 --failing`
completed against the merged directory and analyzed the 9 reward-failing trials.
It wrote `jobs/2026-07-18__08-40-23/analysis.json`.

### `Claude-Sonnet-5`

Command:

```bash
JOB_NAME=claude-sonnet-5 MODEL=Claude-Sonnet-5 INFRA_PARALLEL=6 INFRABENCH_GPU_COUNT=8 ./run_claude_code.sh
```

The job completed 20 trials but Harbor did not write `finished_at` because the
last `llm-fp8-quantize` container stayed up after an `AgentTimeoutError`. I
stopped the stale Harbor process/container after confirming the timeout and
trajectory were present.

Log/result paths:

- `infra-bench/jobs/claude-sonnet-5/run.log`
- `infra-bench/jobs/claude-sonnet-5/result.json`
- `infra-bench/jobs/claude-sonnet-5/llm-fp8-quantize__VESN2SA/exception.txt`
- `infra-bench/jobs/claude-sonnet-5/llm-fp8-quantize__VESN2SA/agent/trajectory.json`

Observed job state:

```text
completed: 20
errored: 6
running: 0
pending: 0
cost_usd: 26.448789
finished_at: null
```

Effective scoreboard for this model, counting the timed-out
`llm-fp8-quantize` as reward 0: **15/20 passed**.

Post-upload-readiness patch: the `llm-fp8-quantize__VESN2SA` timeout trial now
has `verifier/reward.txt` set to `0`, and its trial `result.json` has
`verifier_result.rewards.reward: 0.0`. The top-level `result.json` now counts
20 rewarded trials with reward counts `{'1.0': 15, '0.0': 5}`.

| Task | Reward | Trial | Trajectory |
|---|---:|---|---|
| `cute-layout-composition` | 1 | `cute-layout-composition__XmNCGHo` | `infra-bench/jobs/claude-sonnet-5/cute-layout-composition__XmNCGHo/agent/trajectory.json` |
| `dwconv3d-occupancy` | 1 | `dwconv3d-occupancy__8TPM2gz` | `infra-bench/jobs/claude-sonnet-5/dwconv3d-occupancy__8TPM2gz/agent/trajectory.json` |
| `engram-triton-kernel` | 1 | `engram-triton-kernel__iHPp57v` | `infra-bench/jobs/claude-sonnet-5/engram-triton-kernel__iHPp57v/agent/trajectory.json` |
| `flydsl-cdna4-preshuffle-gemm` | 1 | `flydsl-cdna4-preshuffle-gemm__APZQ2Cs` | `infra-bench/jobs/claude-sonnet-5/flydsl-cdna4-preshuffle-gemm__APZQ2Cs/agent/trajectory.json` |
| `gemm-fp8-ptpc-quant` | 1 | `gemm-fp8-ptpc-quant__hw9pwMk` | `infra-bench/jobs/claude-sonnet-5/gemm-fp8-ptpc-quant__hw9pwMk/agent/trajectory.json` |
| `gemma4-gemm-tuning` | 0 | `gemma4-gemm-tuning__uSsMSHG` | `infra-bench/jobs/claude-sonnet-5/gemma4-gemm-tuning__uSsMSHG/agent/trajectory.json` |
| `gemma4-sglang-serving-opt` | 0 | `gemma4-sglang-serving-opt__gdqrbBC` | `infra-bench/jobs/claude-sonnet-5/gemma4-sglang-serving-opt__gdqrbBC/agent/trajectory.json` |
| `gluon-a8w8-mfma-att` | 1 | `gluon-a8w8-mfma-att__pFtTMno` | `infra-bench/jobs/claude-sonnet-5/gluon-a8w8-mfma-att__pFtTMno/agent/trajectory.json` |
| `hello-rocm` | 1 | `hello-rocm__6uzq3ap` | `infra-bench/jobs/claude-sonnet-5/hello-rocm__6uzq3ap/agent/trajectory.json` |
| `hotspot-analysis-torch-profiler` | 1 | `hotspot-analysis-torch-profiler__Ak4GdSr` | `infra-bench/jobs/claude-sonnet-5/hotspot-analysis-torch-profiler__Ak4GdSr/agent/trajectory.json` |
| `llm-fp8-quantize` | 0 | `llm-fp8-quantize__VESN2SA` | `infra-bench/jobs/claude-sonnet-5/llm-fp8-quantize__VESN2SA/agent/trajectory.json` |
| `llvm-simple-constant-propagation` | 1 | `llvm-simple-constant-propagation__bR4WmTP` | `infra-bench/jobs/claude-sonnet-5/llvm-simple-constant-propagation__bR4WmTP/agent/trajectory.json` |
| `mem-bandwidth-bench` | 1 | `mem-bandwidth-bench__LYRDCDE` | `infra-bench/jobs/claude-sonnet-5/mem-bandwidth-bench__LYRDCDE/agent/trajectory.json` |
| `paged-attention-hd256` | 0 | `paged-attention-hd256__mxXkF6f` | `infra-bench/jobs/claude-sonnet-5/paged-attention-hd256__mxXkF6f/agent/trajectory.json` |
| `pointnet2-hipify` | 1 | `pointnet2-hipify__UAFLf53` | `infra-bench/jobs/claude-sonnet-5/pointnet2-hipify__UAFLf53/agent/trajectory.json` |
| `qr-rmsnorm-fusion` | 0 | `qr-rmsnorm-fusion__wwZd4p9` | `infra-bench/jobs/claude-sonnet-5/qr-rmsnorm-fusion__wwZd4p9/agent/trajectory.json` |
| `sglang-mmmu-ipc-crash` | 1 | `sglang-mmmu-ipc-crash__KgKXTtc` | `infra-bench/jobs/claude-sonnet-5/sglang-mmmu-ipc-crash__KgKXTtc/agent/trajectory.json` |
| `sglang-sync-stall` | 1 | `sglang-sync-stall__cj6wZNe` | `infra-bench/jobs/claude-sonnet-5/sglang-sync-stall__cj6wZNe/agent/trajectory.json` |
| `triton-matmul-tuning` | 1 | `triton-matmul-tuning__fgz7LXA` | `infra-bench/jobs/claude-sonnet-5/triton-matmul-tuning__fgz7LXA/agent/trajectory.json` |
| `vllm-aiter-debug` | 1 | `vllm-aiter-debug__Wze8zEm` | `infra-bench/jobs/claude-sonnet-5/vllm-aiter-debug__Wze8zEm/agent/trajectory.json` |

### `gpt-5.6-sol` via Codex

Command:

```bash
JOB_NAME=codex-gpt-5.6-sol MODEL=gpt-5.6-sol INFRA_PARALLEL=6 INFRABENCH_GPU_COUNT=8 ./run_codex.sh
```

Log excerpt:

```text
infra-bench * codex * gpt-5.6-sol
Trials: 20
Exceptions: 0
Mean: 1.000
Reward 1.0: 20
Total runtime: 1h 31m 29s
Results written to /home/xisun/InfraBench/infra-bench/jobs/codex-gpt-5.6-sol/result.json
```

Scoreboard: **20/20 passed**.

Cost observed: `52.782459` USD.

All 20 trials have agent trajectories under:

- `infra-bench/jobs/codex-gpt-5.6-sol/*/agent/trajectory.json`

Per-task trajectories:

| Task | Reward | Trial | Trajectory |
|---|---:|---|---|
| `cute-layout-composition` | 1 | `cute-layout-composition__FtA83Xq` | `infra-bench/jobs/codex-gpt-5.6-sol/cute-layout-composition__FtA83Xq/agent/trajectory.json` |
| `dwconv3d-occupancy` | 1 | `dwconv3d-occupancy__EmWyB57` | `infra-bench/jobs/codex-gpt-5.6-sol/dwconv3d-occupancy__EmWyB57/agent/trajectory.json` |
| `engram-triton-kernel` | 1 | `engram-triton-kernel__wJcVHfC` | `infra-bench/jobs/codex-gpt-5.6-sol/engram-triton-kernel__wJcVHfC/agent/trajectory.json` |
| `flydsl-cdna4-preshuffle-gemm` | 1 | `flydsl-cdna4-preshuffle-gemm__hCwhgzN` | `infra-bench/jobs/codex-gpt-5.6-sol/flydsl-cdna4-preshuffle-gemm__hCwhgzN/agent/trajectory.json` |
| `gemm-fp8-ptpc-quant` | 1 | `gemm-fp8-ptpc-quant__jxY6V67` | `infra-bench/jobs/codex-gpt-5.6-sol/gemm-fp8-ptpc-quant__jxY6V67/agent/trajectory.json` |
| `gemma4-gemm-tuning` | 1 | `gemma4-gemm-tuning__WC4TCg8` | `infra-bench/jobs/codex-gpt-5.6-sol/gemma4-gemm-tuning__WC4TCg8/agent/trajectory.json` |
| `gemma4-sglang-serving-opt` | 1 | `gemma4-sglang-serving-opt__cPQ24GC` | `infra-bench/jobs/codex-gpt-5.6-sol/gemma4-sglang-serving-opt__cPQ24GC/agent/trajectory.json` |
| `gluon-a8w8-mfma-att` | 1 | `gluon-a8w8-mfma-att__85A6yNk` | `infra-bench/jobs/codex-gpt-5.6-sol/gluon-a8w8-mfma-att__85A6yNk/agent/trajectory.json` |
| `hello-rocm` | 1 | `hello-rocm__mTQR33y` | `infra-bench/jobs/codex-gpt-5.6-sol/hello-rocm__mTQR33y/agent/trajectory.json` |
| `hotspot-analysis-torch-profiler` | 1 | `hotspot-analysis-torch-profiler__D6hThS6` | `infra-bench/jobs/codex-gpt-5.6-sol/hotspot-analysis-torch-profiler__D6hThS6/agent/trajectory.json` |
| `llm-fp8-quantize` | 1 | `llm-fp8-quantize__ySLnUnP` | `infra-bench/jobs/codex-gpt-5.6-sol/llm-fp8-quantize__ySLnUnP/agent/trajectory.json` |
| `llvm-simple-constant-propagation` | 1 | `llvm-simple-constant-propagation__msuaLcD` | `infra-bench/jobs/codex-gpt-5.6-sol/llvm-simple-constant-propagation__msuaLcD/agent/trajectory.json` |
| `mem-bandwidth-bench` | 1 | `mem-bandwidth-bench__DapDwiY` | `infra-bench/jobs/codex-gpt-5.6-sol/mem-bandwidth-bench__DapDwiY/agent/trajectory.json` |
| `paged-attention-hd256` | 1 | `paged-attention-hd256__4W6ij7N` | `infra-bench/jobs/codex-gpt-5.6-sol/paged-attention-hd256__4W6ij7N/agent/trajectory.json` |
| `pointnet2-hipify` | 1 | `pointnet2-hipify__Uxoit2k` | `infra-bench/jobs/codex-gpt-5.6-sol/pointnet2-hipify__Uxoit2k/agent/trajectory.json` |
| `qr-rmsnorm-fusion` | 1 | `qr-rmsnorm-fusion__wTf5Dhw` | `infra-bench/jobs/codex-gpt-5.6-sol/qr-rmsnorm-fusion__wTf5Dhw/agent/trajectory.json` |
| `sglang-mmmu-ipc-crash` | 1 | `sglang-mmmu-ipc-crash__nrALC7b` | `infra-bench/jobs/codex-gpt-5.6-sol/sglang-mmmu-ipc-crash__nrALC7b/agent/trajectory.json` |
| `sglang-sync-stall` | 1 | `sglang-sync-stall__Zd9tSvj` | `infra-bench/jobs/codex-gpt-5.6-sol/sglang-sync-stall__Zd9tSvj/agent/trajectory.json` |
| `triton-matmul-tuning` | 1 | `triton-matmul-tuning__GgmjADR` | `infra-bench/jobs/codex-gpt-5.6-sol/triton-matmul-tuning__GgmjADR/agent/trajectory.json` |
| `vllm-aiter-debug` | 1 | `vllm-aiter-debug__EE67fT9` | `infra-bench/jobs/codex-gpt-5.6-sol/vllm-aiter-debug__EE67fT9/agent/trajectory.json` |

### `gpt-5.6-luna` via Codex

Command:

```bash
JOB_NAME=codex-gpt-5.6-luna MODEL=gpt-5.6-luna INFRA_PARALLEL=6 INFRABENCH_GPU_COUNT=8 ./run_codex.sh
```

Log excerpt:

```text
infra-bench * codex * gpt-5.6-luna
Trials: 19
Exceptions: 1
Mean: 0.900
Reward 1.0: 18
Reward 0.0: 1
Exception AgentTimeoutError: 1
Total runtime: 1h 40m 36s
Results written to /home/xisun/InfraBench/infra-bench/jobs/codex-gpt-5.6-luna/result.json
```

Scoreboard: **18/20 passed**.

Cost observed: `12.158817` USD.

Final job state:

```text
finished_at: 2026-07-17T19:34:10.937835
completed: 20
errored: 1
running: 0
pending: 0
cost_usd: 12.158817
```

Log/result paths:

- `infra-bench/jobs/codex-gpt-5.6-luna/run.log`
- `infra-bench/jobs/codex-gpt-5.6-luna/result.json`
- `infra-bench/jobs/codex-gpt-5.6-luna/llm-fp8-quantize__EmHcaxp/exception.txt`
- `infra-bench/jobs/codex-gpt-5.6-luna/llm-fp8-quantize__EmHcaxp/agent/trajectory.json`

Failure triage:

- `paged-attention-hd256`: verifier reward 0. The verifier reported numerical
  correctness failures for `correct_kv257`, `correct_kv2048`, and
  `perf_shape_correct`.
- `llm-fp8-quantize`: the agent phase timed out after 5400 seconds
  (`AgentTimeoutError`). The agent trajectory exists; for upload-readiness, the
  timeout trial now has `verifier/reward.txt` set to `0`, and its trial
  `result.json` has `verifier_result.rewards.reward: 0.0`. The top-level
  `result.json` now counts 20 rewarded trials with reward counts
  `{'1.0': 18, '0.0': 2}`.

Per-task trajectories:

| Task | Reward | Trial | Trajectory |
|---|---:|---|---|
| `cute-layout-composition` | 1 | `cute-layout-composition__RyPzVc2` | `infra-bench/jobs/codex-gpt-5.6-luna/cute-layout-composition__RyPzVc2/agent/trajectory.json` |
| `dwconv3d-occupancy` | 1 | `dwconv3d-occupancy__rd6zjM8` | `infra-bench/jobs/codex-gpt-5.6-luna/dwconv3d-occupancy__rd6zjM8/agent/trajectory.json` |
| `engram-triton-kernel` | 1 | `engram-triton-kernel__NfQpmTc` | `infra-bench/jobs/codex-gpt-5.6-luna/engram-triton-kernel__NfQpmTc/agent/trajectory.json` |
| `flydsl-cdna4-preshuffle-gemm` | 1 | `flydsl-cdna4-preshuffle-gemm__hb94SG6` | `infra-bench/jobs/codex-gpt-5.6-luna/flydsl-cdna4-preshuffle-gemm__hb94SG6/agent/trajectory.json` |
| `gemm-fp8-ptpc-quant` | 1 | `gemm-fp8-ptpc-quant__Ru2ZCZH` | `infra-bench/jobs/codex-gpt-5.6-luna/gemm-fp8-ptpc-quant__Ru2ZCZH/agent/trajectory.json` |
| `gemma4-gemm-tuning` | 1 | `gemma4-gemm-tuning__Zijp3wZ` | `infra-bench/jobs/codex-gpt-5.6-luna/gemma4-gemm-tuning__Zijp3wZ/agent/trajectory.json` |
| `gemma4-sglang-serving-opt` | 1 | `gemma4-sglang-serving-opt__n6Lz5zn` | `infra-bench/jobs/codex-gpt-5.6-luna/gemma4-sglang-serving-opt__n6Lz5zn/agent/trajectory.json` |
| `gluon-a8w8-mfma-att` | 1 | `gluon-a8w8-mfma-att__cuFjErS` | `infra-bench/jobs/codex-gpt-5.6-luna/gluon-a8w8-mfma-att__cuFjErS/agent/trajectory.json` |
| `hello-rocm` | 1 | `hello-rocm__6v6DGAn` | `infra-bench/jobs/codex-gpt-5.6-luna/hello-rocm__6v6DGAn/agent/trajectory.json` |
| `hotspot-analysis-torch-profiler` | 1 | `hotspot-analysis-torch-profiler__QbnjpAg` | `infra-bench/jobs/codex-gpt-5.6-luna/hotspot-analysis-torch-profiler__QbnjpAg/agent/trajectory.json` |
| `llm-fp8-quantize` | 0 | `llm-fp8-quantize__EmHcaxp` | `infra-bench/jobs/codex-gpt-5.6-luna/llm-fp8-quantize__EmHcaxp/agent/trajectory.json` |
| `llvm-simple-constant-propagation` | 1 | `llvm-simple-constant-propagation__chkEW5a` | `infra-bench/jobs/codex-gpt-5.6-luna/llvm-simple-constant-propagation__chkEW5a/agent/trajectory.json` |
| `mem-bandwidth-bench` | 1 | `mem-bandwidth-bench__zPxgFxy` | `infra-bench/jobs/codex-gpt-5.6-luna/mem-bandwidth-bench__zPxgFxy/agent/trajectory.json` |
| `paged-attention-hd256` | 0 | `paged-attention-hd256__ctqNnaf` | `infra-bench/jobs/codex-gpt-5.6-luna/paged-attention-hd256__ctqNnaf/agent/trajectory.json` |
| `pointnet2-hipify` | 1 | `pointnet2-hipify__9xPAm4Q` | `infra-bench/jobs/codex-gpt-5.6-luna/pointnet2-hipify__9xPAm4Q/agent/trajectory.json` |
| `qr-rmsnorm-fusion` | 1 | `qr-rmsnorm-fusion__8tbTZgX` | `infra-bench/jobs/codex-gpt-5.6-luna/qr-rmsnorm-fusion__8tbTZgX/agent/trajectory.json` |
| `sglang-mmmu-ipc-crash` | 1 | `sglang-mmmu-ipc-crash__uPsuApq` | `infra-bench/jobs/codex-gpt-5.6-luna/sglang-mmmu-ipc-crash__uPsuApq/agent/trajectory.json` |
| `sglang-sync-stall` | 1 | `sglang-sync-stall__AZRQwdL` | `infra-bench/jobs/codex-gpt-5.6-luna/sglang-sync-stall__AZRQwdL/agent/trajectory.json` |
| `triton-matmul-tuning` | 1 | `triton-matmul-tuning__YEMAUXT` | `infra-bench/jobs/codex-gpt-5.6-luna/triton-matmul-tuning__YEMAUXT/agent/trajectory.json` |
| `vllm-aiter-debug` | 1 | `vllm-aiter-debug__UmqAwjQ` | `infra-bench/jobs/codex-gpt-5.6-luna/vllm-aiter-debug__UmqAwjQ/agent/trajectory.json` |

### `gpt-5.5` via Codex

Command:

```bash
JOB_NAME=codex-gpt-5.5 MODEL=gpt-5.5 INFRA_PARALLEL=6 INFRABENCH_GPU_COUNT=8 ./run_codex.sh
```

Log excerpt:

```text
infra-bench * codex * gpt-5.5
Trials: 20
Exceptions: 0
Mean: 0.850
Reward 1.0: 17
Reward 0.0: 3
Total runtime: 59m 53s
Results written to /home/xisun/InfraBench/infra-bench/jobs/codex-gpt-5.5/result.json
[run_codex.sh] 17/20 passed
```

Final job state:

```text
finished_at: 2026-07-17T20:36:27.857947
completed: 20
errored: 0
running: 0
pending: 0
cost_usd: 42.659779
```

Scoreboard: **17/20 passed**.

Cost observed: `42.659779` USD.

Reward-0 trials had no `exception.txt`, so they are counted as verifier/model
failures rather than infra failures:

- `cute-layout-composition__WMc3nDT`
- `flydsl-cdna4-preshuffle-gemm__yvMojS8`
- `paged-attention-hd256__AU6ELff`

Per-task trajectories:

| Task | Reward | Trial | Trajectory |
|---|---:|---|---|
| `cute-layout-composition` | 0 | `cute-layout-composition__WMc3nDT` | `infra-bench/jobs/codex-gpt-5.5/cute-layout-composition__WMc3nDT/agent/trajectory.json` |
| `dwconv3d-occupancy` | 1 | `dwconv3d-occupancy__LGEw9Z2` | `infra-bench/jobs/codex-gpt-5.5/dwconv3d-occupancy__LGEw9Z2/agent/trajectory.json` |
| `engram-triton-kernel` | 1 | `engram-triton-kernel__iotJQAT` | `infra-bench/jobs/codex-gpt-5.5/engram-triton-kernel__iotJQAT/agent/trajectory.json` |
| `flydsl-cdna4-preshuffle-gemm` | 0 | `flydsl-cdna4-preshuffle-gemm__yvMojS8` | `infra-bench/jobs/codex-gpt-5.5/flydsl-cdna4-preshuffle-gemm__yvMojS8/agent/trajectory.json` |
| `gemm-fp8-ptpc-quant` | 1 | `gemm-fp8-ptpc-quant__k2MRmzR` | `infra-bench/jobs/codex-gpt-5.5/gemm-fp8-ptpc-quant__k2MRmzR/agent/trajectory.json` |
| `gemma4-gemm-tuning` | 1 | `gemma4-gemm-tuning__v3PDc6m` | `infra-bench/jobs/codex-gpt-5.5/gemma4-gemm-tuning__v3PDc6m/agent/trajectory.json` |
| `gemma4-sglang-serving-opt` | 1 | `gemma4-sglang-serving-opt__uU8srsi` | `infra-bench/jobs/codex-gpt-5.5/gemma4-sglang-serving-opt__uU8srsi/agent/trajectory.json` |
| `gluon-a8w8-mfma-att` | 1 | `gluon-a8w8-mfma-att__bj4pz4b` | `infra-bench/jobs/codex-gpt-5.5/gluon-a8w8-mfma-att__bj4pz4b/agent/trajectory.json` |
| `hello-rocm` | 1 | `hello-rocm__LgBPAyV` | `infra-bench/jobs/codex-gpt-5.5/hello-rocm__LgBPAyV/agent/trajectory.json` |
| `hotspot-analysis-torch-profiler` | 1 | `hotspot-analysis-torch-profiler__7vKD4zd` | `infra-bench/jobs/codex-gpt-5.5/hotspot-analysis-torch-profiler__7vKD4zd/agent/trajectory.json` |
| `llm-fp8-quantize` | 1 | `llm-fp8-quantize__HBDBMNe` | `infra-bench/jobs/codex-gpt-5.5/llm-fp8-quantize__HBDBMNe/agent/trajectory.json` |
| `llvm-simple-constant-propagation` | 1 | `llvm-simple-constant-propagation__HFCUboS` | `infra-bench/jobs/codex-gpt-5.5/llvm-simple-constant-propagation__HFCUboS/agent/trajectory.json` |
| `mem-bandwidth-bench` | 1 | `mem-bandwidth-bench__bQENywe` | `infra-bench/jobs/codex-gpt-5.5/mem-bandwidth-bench__bQENywe/agent/trajectory.json` |
| `paged-attention-hd256` | 0 | `paged-attention-hd256__AU6ELff` | `infra-bench/jobs/codex-gpt-5.5/paged-attention-hd256__AU6ELff/agent/trajectory.json` |
| `pointnet2-hipify` | 1 | `pointnet2-hipify__DgFMg9j` | `infra-bench/jobs/codex-gpt-5.5/pointnet2-hipify__DgFMg9j/agent/trajectory.json` |
| `qr-rmsnorm-fusion` | 1 | `qr-rmsnorm-fusion__ioKc4g5` | `infra-bench/jobs/codex-gpt-5.5/qr-rmsnorm-fusion__ioKc4g5/agent/trajectory.json` |
| `sglang-mmmu-ipc-crash` | 1 | `sglang-mmmu-ipc-crash__DCLQMDJ` | `infra-bench/jobs/codex-gpt-5.5/sglang-mmmu-ipc-crash__DCLQMDJ/agent/trajectory.json` |
| `sglang-sync-stall` | 1 | `sglang-sync-stall__HC8vnt3` | `infra-bench/jobs/codex-gpt-5.5/sglang-sync-stall__HC8vnt3/agent/trajectory.json` |
| `triton-matmul-tuning` | 1 | `triton-matmul-tuning__MSm7EkX` | `infra-bench/jobs/codex-gpt-5.5/triton-matmul-tuning__MSm7EkX/agent/trajectory.json` |
| `vllm-aiter-debug` | 1 | `vllm-aiter-debug__Lgt6JNw` | `infra-bench/jobs/codex-gpt-5.5/vllm-aiter-debug__Lgt6JNw/agent/trajectory.json` |

### `DeepSeek-V4-Flash` via OpenCode

Command:

```bash
JOB_NAME=opencode-deepseek-v4-flash MODEL=DeepSeek-V4-Flash AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' INFRA_PARALLEL=6 INFRABENCH_GPU_COUNT=8 ./run_open_code.sh
```

Log excerpt:

```text
infra-bench * opencode * DeepSeek-V4-Flash
Trials: 20
Exceptions: 7
Mean: 0.450
Reward 1.0: 9
Reward 0.0: 11
Exception NonZeroAgentExitCodeError: 3
Exception AgentTimeoutError: 4
Total runtime: 2h 8m 7s
Results written to /home/xisun/InfraBench/infra-bench/jobs/opencode-deepseek-v4-flash/result.json
[run_open_code.sh] 9/20 passed
```

Final job state:

```text
finished_at: 2026-07-17T22:45:21.335886
completed: 20
errored: 7
running: 0
pending: 0
cost_usd: 1.777992
```

Scoreboard: **9/20 passed**.

Cost observed: `1.777992` USD.

Failure triage:

- `AgentTimeoutError`: `engram-triton-kernel__UhQUW3u`,
  `flydsl-cdna4-preshuffle-gemm__trfNL8V`,
  `gemma4-sglang-serving-opt__ywyxXn2`, `llm-fp8-quantize__2R65RVH`.
- `NonZeroAgentExitCodeError`: `hotspot-analysis-torch-profiler__Vn2WQcY`
  exited 137; `sglang-sync-stall__xVKWaxX` and
  `vllm-aiter-debug__MuYhh38` exited 143.
- Reward-0 trials without `exception.txt`: `cute-layout-composition__7fKuqps`,
  `dwconv3d-occupancy__qt9MSg8`, `gemma4-gemm-tuning__Z7BY3ce`,
  `paged-attention-hd256__hmwe7m6`.

Per-task trajectories:

| Task | Reward | Trial | Agent artifact |
|---|---:|---|---|
| `cute-layout-composition` | 0 | `cute-layout-composition__7fKuqps` | `infra-bench/jobs/opencode-deepseek-v4-flash/cute-layout-composition__7fKuqps/agent/trajectory.json` |
| `dwconv3d-occupancy` | 0 | `dwconv3d-occupancy__qt9MSg8` | `infra-bench/jobs/opencode-deepseek-v4-flash/dwconv3d-occupancy__qt9MSg8/agent/trajectory.json` |
| `engram-triton-kernel` | 0 | `engram-triton-kernel__UhQUW3u` | `infra-bench/jobs/opencode-deepseek-v4-flash/engram-triton-kernel__UhQUW3u/agent/opencode.txt` (`trajectory.json` missing) |
| `flydsl-cdna4-preshuffle-gemm` | 0 | `flydsl-cdna4-preshuffle-gemm__trfNL8V` | `infra-bench/jobs/opencode-deepseek-v4-flash/flydsl-cdna4-preshuffle-gemm__trfNL8V/agent/trajectory.json` |
| `gemm-fp8-ptpc-quant` | 1 | `gemm-fp8-ptpc-quant__uUC3cPt` | `infra-bench/jobs/opencode-deepseek-v4-flash/gemm-fp8-ptpc-quant__uUC3cPt/agent/trajectory.json` |
| `gemma4-gemm-tuning` | 0 | `gemma4-gemm-tuning__Z7BY3ce` | `infra-bench/jobs/opencode-deepseek-v4-flash/gemma4-gemm-tuning__Z7BY3ce/agent/trajectory.json` |
| `gemma4-sglang-serving-opt` | 0 | `gemma4-sglang-serving-opt__ywyxXn2` | `infra-bench/jobs/opencode-deepseek-v4-flash/gemma4-sglang-serving-opt__ywyxXn2/agent/opencode.txt` (`trajectory.json` missing) |
| `gluon-a8w8-mfma-att` | 1 | `gluon-a8w8-mfma-att__QFhKevp` | `infra-bench/jobs/opencode-deepseek-v4-flash/gluon-a8w8-mfma-att__QFhKevp/agent/trajectory.json` |
| `hello-rocm` | 1 | `hello-rocm__E7tjqu5` | `infra-bench/jobs/opencode-deepseek-v4-flash/hello-rocm__E7tjqu5/agent/trajectory.json` |
| `hotspot-analysis-torch-profiler` | 0 | `hotspot-analysis-torch-profiler__Vn2WQcY` | `infra-bench/jobs/opencode-deepseek-v4-flash/hotspot-analysis-torch-profiler__Vn2WQcY/agent/trajectory.json` |
| `llm-fp8-quantize` | 0 | `llm-fp8-quantize__2R65RVH` | `infra-bench/jobs/opencode-deepseek-v4-flash/llm-fp8-quantize__2R65RVH/agent/trajectory.json` |
| `llvm-simple-constant-propagation` | 1 | `llvm-simple-constant-propagation__RMEedmN` | `infra-bench/jobs/opencode-deepseek-v4-flash/llvm-simple-constant-propagation__RMEedmN/agent/trajectory.json` |
| `mem-bandwidth-bench` | 1 | `mem-bandwidth-bench__8XSeKY7` | `infra-bench/jobs/opencode-deepseek-v4-flash/mem-bandwidth-bench__8XSeKY7/agent/trajectory.json` |
| `paged-attention-hd256` | 0 | `paged-attention-hd256__hmwe7m6` | `infra-bench/jobs/opencode-deepseek-v4-flash/paged-attention-hd256__hmwe7m6/agent/trajectory.json` |
| `pointnet2-hipify` | 1 | `pointnet2-hipify__xcpRbdW` | `infra-bench/jobs/opencode-deepseek-v4-flash/pointnet2-hipify__xcpRbdW/agent/trajectory.json` |
| `qr-rmsnorm-fusion` | 1 | `qr-rmsnorm-fusion__7k8mhWv` | `infra-bench/jobs/opencode-deepseek-v4-flash/qr-rmsnorm-fusion__7k8mhWv/agent/trajectory.json` |
| `sglang-mmmu-ipc-crash` | 1 | `sglang-mmmu-ipc-crash__wqawpbj` | `infra-bench/jobs/opencode-deepseek-v4-flash/sglang-mmmu-ipc-crash__wqawpbj/agent/trajectory.json` |
| `sglang-sync-stall` | 0 | `sglang-sync-stall__xVKWaxX` | `infra-bench/jobs/opencode-deepseek-v4-flash/sglang-sync-stall__xVKWaxX/agent/trajectory.json` |
| `triton-matmul-tuning` | 1 | `triton-matmul-tuning__MgrbdBh` | `infra-bench/jobs/opencode-deepseek-v4-flash/triton-matmul-tuning__MgrbdBh/agent/trajectory.json` |
| `vllm-aiter-debug` | 0 | `vllm-aiter-debug__MuYhh38` | `infra-bench/jobs/opencode-deepseek-v4-flash/vllm-aiter-debug__MuYhh38/agent/trajectory.json` |

### `MiniMax-M2.7` via OpenCode

Command:

```bash
JOB_NAME=opencode-minimax-m2.7 MODEL=MiniMax-M2.7 AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' INFRA_PARALLEL=6 INFRABENCH_GPU_COUNT=8 ./run_open_code.sh
```

Log excerpt:

```text
infra-bench * opencode * MiniMax-M2.7
Trials: 20
Exceptions: 7
Mean: 0.200
Reward 1.0: 4
Reward 0.0: 16
Exception NonZeroAgentExitCodeError: 4
Exception ApiRateLimitError: 1
Exception AgentTimeoutError: 2
Total runtime: 1h 9m 49s
Results written to /home/xisun/InfraBench/infra-bench/jobs/opencode-minimax-m2.7/result.json
[run_open_code.sh] 4/20 passed
```

Final job state:

```text
finished_at: 2026-07-17T23:56:16.142574
completed: 20
errored: 7
running: 0
pending: 0
cost_usd: 1.861118
```

Scoreboard: **4/20 passed**.

Cost observed: `1.861118` USD.

Failure and exception triage:

- `AgentTimeoutError`: `flydsl-cdna4-preshuffle-gemm__Xt82KMm`,
  `gemma4-sglang-serving-opt__5DNSYr6`; both had reward 0.
- `NonZeroAgentExitCodeError`: `pointnet2-hipify__cgDCVwL`,
  `qr-rmsnorm-fusion__9J4Zghs`, `vllm-aiter-debug__quVsD5B` with reward 0,
  and `triton-matmul-tuning__3WnZizA` with reward 1.
- `ApiRateLimitError`: `hotspot-analysis-torch-profiler__4NYnj3c`; Harbor still
  recorded reward 1 for this trial, so it is counted as passed in the reward
  scoreboard.

Per-task trajectories:

| Task | Reward | Trial | Trajectory |
|---|---:|---|---|
| `cute-layout-composition` | 0 | `cute-layout-composition__qWjRKVh` | `infra-bench/jobs/opencode-minimax-m2.7/cute-layout-composition__qWjRKVh/agent/trajectory.json` |
| `dwconv3d-occupancy` | 0 | `dwconv3d-occupancy__vkFDvfC` | `infra-bench/jobs/opencode-minimax-m2.7/dwconv3d-occupancy__vkFDvfC/agent/trajectory.json` |
| `engram-triton-kernel` | 0 | `engram-triton-kernel__R4Vc8ef` | `infra-bench/jobs/opencode-minimax-m2.7/engram-triton-kernel__R4Vc8ef/agent/trajectory.json` |
| `flydsl-cdna4-preshuffle-gemm` | 0 | `flydsl-cdna4-preshuffle-gemm__Xt82KMm` | `infra-bench/jobs/opencode-minimax-m2.7/flydsl-cdna4-preshuffle-gemm__Xt82KMm/agent/trajectory.json` |
| `gemm-fp8-ptpc-quant` | 0 | `gemm-fp8-ptpc-quant__8girp9a` | `infra-bench/jobs/opencode-minimax-m2.7/gemm-fp8-ptpc-quant__8girp9a/agent/trajectory.json` |
| `gemma4-gemm-tuning` | 0 | `gemma4-gemm-tuning__brf6ZM5` | `infra-bench/jobs/opencode-minimax-m2.7/gemma4-gemm-tuning__brf6ZM5/agent/trajectory.json` |
| `gemma4-sglang-serving-opt` | 0 | `gemma4-sglang-serving-opt__5DNSYr6` | `infra-bench/jobs/opencode-minimax-m2.7/gemma4-sglang-serving-opt__5DNSYr6/agent/trajectory.json` |
| `gluon-a8w8-mfma-att` | 1 | `gluon-a8w8-mfma-att__HQp5nbo` | `infra-bench/jobs/opencode-minimax-m2.7/gluon-a8w8-mfma-att__HQp5nbo/agent/trajectory.json` |
| `hello-rocm` | 1 | `hello-rocm__VERh9rZ` | `infra-bench/jobs/opencode-minimax-m2.7/hello-rocm__VERh9rZ/agent/trajectory.json` |
| `hotspot-analysis-torch-profiler` | 1 | `hotspot-analysis-torch-profiler__4NYnj3c` | `infra-bench/jobs/opencode-minimax-m2.7/hotspot-analysis-torch-profiler__4NYnj3c/agent/trajectory.json` |
| `llm-fp8-quantize` | 0 | `llm-fp8-quantize__KUtSdDk` | `infra-bench/jobs/opencode-minimax-m2.7/llm-fp8-quantize__KUtSdDk/agent/trajectory.json` |
| `llvm-simple-constant-propagation` | 0 | `llvm-simple-constant-propagation__vqx8Cp2` | `infra-bench/jobs/opencode-minimax-m2.7/llvm-simple-constant-propagation__vqx8Cp2/agent/trajectory.json` |
| `mem-bandwidth-bench` | 0 | `mem-bandwidth-bench__6ymcTaq` | `infra-bench/jobs/opencode-minimax-m2.7/mem-bandwidth-bench__6ymcTaq/agent/trajectory.json` |
| `paged-attention-hd256` | 0 | `paged-attention-hd256__emmxJGk` | `infra-bench/jobs/opencode-minimax-m2.7/paged-attention-hd256__emmxJGk/agent/trajectory.json` |
| `pointnet2-hipify` | 0 | `pointnet2-hipify__cgDCVwL` | `infra-bench/jobs/opencode-minimax-m2.7/pointnet2-hipify__cgDCVwL/agent/trajectory.json` |
| `qr-rmsnorm-fusion` | 0 | `qr-rmsnorm-fusion__9J4Zghs` | `infra-bench/jobs/opencode-minimax-m2.7/qr-rmsnorm-fusion__9J4Zghs/agent/trajectory.json` |
| `sglang-mmmu-ipc-crash` | 0 | `sglang-mmmu-ipc-crash__Pa3Bpu7` | `infra-bench/jobs/opencode-minimax-m2.7/sglang-mmmu-ipc-crash__Pa3Bpu7/agent/trajectory.json` |
| `sglang-sync-stall` | 0 | `sglang-sync-stall__RARXyxQ` | `infra-bench/jobs/opencode-minimax-m2.7/sglang-sync-stall__RARXyxQ/agent/trajectory.json` |
| `triton-matmul-tuning` | 1 | `triton-matmul-tuning__3WnZizA` | `infra-bench/jobs/opencode-minimax-m2.7/triton-matmul-tuning__3WnZizA/agent/trajectory.json` |
| `vllm-aiter-debug` | 0 | `vllm-aiter-debug__quVsD5B` | `infra-bench/jobs/opencode-minimax-m2.7/vllm-aiter-debug__quVsD5B/agent/trajectory.json` |

## Aggregate Scoreboard

The Claude Opus and Haiku rows use synthetic merged upload directories. The
Sonnet and Luna rows include timeout `llm-fp8-quantize` trials explicitly marked
as reward 0 for upload-readiness. Median latency is the median per-trial
`agent_execution` duration from each selected trial's `result.json`; all rows
had timing data for 20/20 selected trials.

Upload metadata normalization: Claude Code trial `agent_info.model_info.provider`
is set to `anthropic`; Codex job, trial config, lock, and result agent names are
set to `codex` rather than the local wrapper import path.

Harbor upload status: the seven strict-valid full jobs were uploaded on
2026-07-18 with `uvx harbor upload -c 4`. Harbor reported each upload as
`Uploaded 20 trial(s)` with private visibility.

| Local job | Hub job ID | Visibility |
|---|---|---|
| `claude-opus-4.6` | `a90d0047-197c-4f11-8ce1-9ed10e40a0e9` | private |
| `claude-haiku-4.5` | `3a10297d-4e78-4690-8995-ce5243295638` | private |
| `claude-sonnet-5` | `6f9e0332-189a-4bb1-b9de-043e1c3e0883` | private |
| `codex-gpt-5.6-sol` | `f6c5c85b-41ae-4302-815a-1dc34817dc7c` | private |
| `codex-gpt-5.6-luna` | `d5000fb4-6617-46aa-b938-f5c48a5f5496` | private |
| `codex-gpt-5.5` | `ed1ee1c0-d1dc-4ffe-a69d-29cf9d2ec390` | private |
| `opencode-minimax-m2.7` | `e657b921-ee6e-4e1c-9db2-fe6e37b180af` | private |

| Agent | Model | Job(s) used | Pass rate | Cost USD | Median agent execution | Exceptions | Structured trajectories missing |
|---|---|---|---:|---:|---:|---:|---:|
| claude-code | `claude-opus-4.6` | `claude-opus-4.6` synthetic merged job | 16/20 | 86.807045 | 6m 50s | 4 | 0 |
| claude-code | `claude-haiku-4.5` | `claude-haiku-4.5` synthetic merged job | 11/20 | 51.780563 | 4m 32s | 1 | 0 |
| claude-code | `Claude-Sonnet-5` | `claude-sonnet-5` | 15/20 | 26.448789 | 7m 35s | 6 | 0 |
| codex | `gpt-5.6-sol` | `codex-gpt-5.6-sol` | 20/20 | 52.782459 | 16m 19s | 0 | 0 |
| codex | `gpt-5.6-luna` | `codex-gpt-5.6-luna` | 18/20 | 12.158817 | 11m 26s | 1 | 0 |
| codex | `gpt-5.5` | `codex-gpt-5.5` | 17/20 | 42.659779 | 6m 41s | 0 | 0 |
| opencode | `DeepSeek-V4-Flash` | `opencode-deepseek-v4-flash` | 9/20 | 1.777992 | 5m 47s | 7 | 2 |
| opencode | `MiniMax-M2.7` | `opencode-minimax-m2.7` | 4/20 | 1.861118 | 4m 13s | 7 | 0 |

DeepSeek's two missing structured trajectories are
`engram-triton-kernel__UhQUW3u` and `gemma4-sglang-serving-opt__ywyxXn2`.
Both still have raw OpenCode logs at `agent/opencode.txt`, and those paths are
listed in the DeepSeek per-task table above.

The original uploaded sweeps from `docs/infra-bench-test-plan.md` have been
executed. The expanded opencode set added afterward is pending:
`DeepSeek-V4-Flash` retest, `Kimi-K2.7-Code`, `Grok-4.3`,
`Qwen3.6-35B-A3B`, `gemini-3.5-flash`, and `Gemma-4-31B`.
