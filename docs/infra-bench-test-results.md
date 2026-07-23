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

The job completed 20 trials but Harbor initially did not write top-level
`finished_at` because the last `llm-fp8-quantize` container stayed up after an
`AgentTimeoutError`. I stopped the stale Harbor process/container after
confirming the timeout and trajectory were present. The first Hub upload used
the upload/finalization time as `finished_at`, which made the Hub duration show
about 18h 51m instead of the real 1h 42m run span.

Timestamp repair: local `result.json` was backed up to
`infra-bench/jobs_bk/claude-sonnet-5-result-timestamp-fix-20260719-002029/`,
then patched to normalize the aggregate `started_at` to UTC and fill
`finished_at` from the final job update. The deleted Hub job was re-uploaded
with the same UUID. Hub now stores:

```text
started_at: 2026-07-17T19:26:52.146627+00:00
finished_at: 2026-07-17T21:09:30.170858+00:00
```

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
started_at: 2026-07-17T19:26:52.146627Z
updated_at: 2026-07-17T21:09:30.170858Z
finished_at: 2026-07-17T21:09:30.170858Z
duration: 1:42:38.024231
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

Historical note: this subsection records the first DeepSeek sweep. The local
`infra-bench/jobs/opencode-deepseek-v4-flash` directory was later replaced by
the Round 2 retest artifacts under the same canonical job name; use the Round 2
DeepSeek section below for the current local/upload candidate.

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

Harbor upload status: the initial strict-valid full jobs were uploaded on
2026-07-18 with private visibility. The Round 2 full-sweep upload candidates
were uploaded on 2026-07-19 with `harbor upload`, also with private visibility;
`opencode-minimax-m2.7` was already present on Hub and was not re-uploaded.
The Round 3 `codex-gpt-5.6-terra` job, the Round 4
`opencode-glm-5.2-fp8-onprem` job, and the Round 5
`opencode-minimax-m3-onprem` job were uploaded on 2026-07-19 with private
visibility.

| Local job | Hub job ID | Visibility |
|---|---|---|
| `claude-opus-4.6` | `a90d0047-197c-4f11-8ce1-9ed10e40a0e9` | private |
| `claude-haiku-4.5` | `3a10297d-4e78-4690-8995-ce5243295638` | private |
| `claude-sonnet-5` | `6f9e0332-189a-4bb1-b9de-043e1c3e0883` | private |
| `codex-gpt-5.6-sol` | `f6c5c85b-41ae-4302-815a-1dc34817dc7c` | private |
| `codex-gpt-5.6-luna` | `d5000fb4-6617-46aa-b938-f5c48a5f5496` | private |
| `codex-gpt-5.5` | `ed1ee1c0-d1dc-4ffe-a69d-29cf9d2ec390` | private |
| `opencode-deepseek-v4-flash` | `c4f9b472-5914-4f5c-9494-d80dd70e8478` | private |
| `opencode-kimi-k2.6` | `c8cce8f0-5be5-4c9b-aa7d-0e20323f1637` | private |
| `opencode-qwen3.6-35b-a3b` | `1dac5cff-f1da-4225-a6a9-e8e3ba017f40` | private |
| `opencode-gemini-3.5-flash` | `8365292f-6ea6-4968-9215-69f8574ddbaa` | private |
| `opencode-gemma-4-31b` | `9207e832-9f29-4366-95bf-ae699e14f0af` | private |
| `opencode-minimax-m2.7` | `e657b921-ee6e-4e1c-9db2-fe6e37b180af` | private |
| `claude-opus-4.8` | `c44aee94-9864-441f-abd3-5c7d81718828` | private |
| `codex-gpt-5.6-terra` | `34d208b6-9be5-4598-8485-e28e404e4974` | private |
| `opencode-glm-5.2-fp8-onprem` | `4d6acd5f-a155-4c7b-bc77-c844a9819772` | private |
| `opencode-minimax-m3-onprem` | `a3dd9a27-c6a5-4ca4-82dd-2c09b36f0970` | private |

| Agent | Model | Job(s) used | Pass rate | Cost USD | Median agent execution | Exceptions | Structured trajectories missing |
|---|---|---|---:|---:|---:|---:|---:|
| claude-code | `claude-opus-4.6` | `claude-opus-4.6` synthetic merged job | 16/20 | 86.807045 | 6m 50s | 4 | 0 |
| claude-code | `claude-haiku-4.5` | `claude-haiku-4.5` synthetic merged job | 11/20 | 51.780563 | 4m 32s | 1 | 0 |
| claude-code | `Claude-Sonnet-5` | `claude-sonnet-5` | 15/20 | 26.448789 | 7m 35s | 6 | 0 |
| codex | `gpt-5.6-sol` | `codex-gpt-5.6-sol` | 20/20 | 52.782459 | 16m 19s | 0 | 0 |
| codex | `gpt-5.6-luna` | `codex-gpt-5.6-luna` | 18/20 | 12.158817 | 11m 26s | 1 | 0 |
| codex | `gpt-5.5` | `codex-gpt-5.5` | 17/20 | 42.659779 | 6m 41s | 0 | 0 |
| codex | `gpt-5.6-terra` | `codex-gpt-5.6-terra` | 18/20 | 13.849469 | 6m 59s | 0 | 0 |
| opencode | `DeepSeek-V4-Flash` | `opencode-deepseek-v4-flash` | 9/20 | 1.777992 | 5m 47s | 7 | 2 |
| opencode | `MiniMax-M2.7` | `opencode-minimax-m2.7` | 4/20 | 1.861118 | 4m 13s | 7 | 0 |

DeepSeek's two missing structured trajectories are
`engram-triton-kernel__UhQUW3u` and `gemma4-sglang-serving-opt__ywyxXn2`.
In the first sweep, both still had raw OpenCode logs at `agent/opencode.txt`;
the local canonical job directory now points to the Round 2 retest artifacts.

## Round 2 Results

Run date: 2026-07-18

Round 2 was added after the original upload batch. This section records the
completed round-2 smoke tests and full sweeps.

### Round 2 Smoke Tests

| Agent | Model | Job | Reward | Cost USD | Run log | Trajectory/log |
|---|---|---|---:|---:|---|---|
| opencode | `DeepSeek-V4-Flash` | `smoke-opencode-deepseek-v4-flash` | 1/1 | 0.002320 | `infra-bench/jobs/smoke-opencode-deepseek-v4-flash/run.log` | `infra-bench/jobs/smoke-opencode-deepseek-v4-flash/hello-rocm__2nMgGnT/agent/trajectory.json` |
| opencode | `Kimi-K2.6` | `smoke-opencode-kimi-k2.6` | 1/1 | 0.013259 | `infra-bench/jobs/smoke-opencode-kimi-k2.6/run.log` | `infra-bench/jobs/smoke-opencode-kimi-k2.6/hello-rocm__KCBhCUG/agent/trajectory.json` |
| opencode | `Qwen3.6-35B-A3B` | `smoke-opencode-qwen3.6-35b-a3b` | 1/1 | 0.006306 | `infra-bench/jobs/smoke-opencode-qwen3.6-35b-a3b/run.log` | `infra-bench/jobs/smoke-opencode-qwen3.6-35b-a3b/hello-rocm__H7VF7T5/agent/trajectory.json` |
| opencode | `gemini-3.5-flash` | `smoke-opencode-gemini-3.5-flash` | 1/1 | 0.157678 | `infra-bench/jobs/smoke-opencode-gemini-3.5-flash/run.log` | `infra-bench/jobs/smoke-opencode-gemini-3.5-flash/hello-rocm__5cMuUPF/agent/trajectory.json` |
| opencode | `Gemma-4-31B` | `smoke-opencode-gemma-4-31b` | 1/1 | 0.003052 | `infra-bench/jobs/smoke-opencode-gemma-4-31b/run.log` | `infra-bench/jobs/smoke-opencode-gemma-4-31b/hello-rocm__RJsvaKs/agent/trajectory.json` |
| claude-code | `claude-opus-4.8` | `smoke-claude-opus-4.8` | 1/1 | 2.436881 | `infra-bench/jobs/smoke-claude-opus-4.8/run.log` | `infra-bench/jobs/smoke-claude-opus-4.8/hello-rocm__EzMHYco/agent/trajectory.json` |

### Round 2 Aggregate Scoreboard

| Agent | Model | Job | Pass rate | Cost USD | Median agent execution | Exceptions | Structured trajectories missing |
|---|---|---|---:|---:|---:|---:|---:|
| opencode | `DeepSeek-V4-Flash` | `opencode-deepseek-v4-flash` | 9/20 | 1.578295 | 9m 36s | 6 | 2 |
| opencode | `Kimi-K2.6` | `opencode-kimi-k2.6` | 11/20 | 13.721151 | 5m 49s | 4 | 0 |
| opencode | `Qwen3.6-35B-A3B` | `opencode-qwen3.6-35b-a3b` | 2/20 | 1.677487 | 50m 22s | 13 | 1 |
| opencode | `gemini-3.5-flash` | `opencode-gemini-3.5-flash` | 14/20 | 173.511468 | 7m 2s | 5 | 0 |
| opencode | `Gemma-4-31B` | `opencode-gemma-4-31b` | 1/20 | 0.409919 | 26m 12s | 5 | 0 |
| claude-code | `claude-opus-4.8` | `claude-opus-4.8` | 16/20 | 69.782510 | 5m 15s | 4 | 0 |

Upload metadata note: before uploading `claude-opus-4.8`, its 20 trial
`agent_info.model_info.provider` values were normalized from `null` to
`anthropic` so the Hub provider column matches the other Claude Code uploads.
The pre-patch trial `result.json` files were backed up under
`infra-bench/jobs_bk/claude-opus-4.8-provider-fix-20260719-003903/`.

`MiniMax-M2.7` remains covered by the original completed OpenCode sweep
`opencode-minimax-m2.7` above: 4/20 passed, cost `1.861118`, 20 reward files,
and no missing structured trajectories. It was not rerun in this round because
the round-2 OpenCode work focused on the DeepSeek retest plus the newly added
models.

OpenCode note: the completed round-2 OpenCode jobs all have 20 trial
`result.json` files and 20 verifier reward files. Some reward-0 trials have
only raw OpenCode logs instead of structured `agent/trajectory.json`; those
are counted in the aggregate table and shown as `agent/opencode.txt` in the
per-task tables below.

The OpenCode runner printed a shell syntax error after some Harbor summaries
while entering its local post-run reward-summary block. Harbor had already
written the job `result.json` and per-trial rewards; the saved job artifacts
are the source of truth for the tables below.

### `DeepSeek-V4-Flash` via OpenCode

Command:

```bash
JOB_NAME=opencode-deepseek-v4-flash MODEL=DeepSeek-V4-Flash AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' INFRA_PARALLEL=6 INFRABENCH_GPU_COUNT=8 ./run_open_code.sh
```

Result summary:

```text
Trials: 20
Exceptions: 6
Reward 1.0: 9
Reward 0.0: 11
Cost USD: 1.578295
Median agent execution: 9m 36s
Results written to /home/xisun/InfraBench/infra-bench/jobs/opencode-deepseek-v4-flash/result.json
```

Exception counts: `AgentTimeoutError`=5, `NonZeroAgentExitCodeError`=1.

Structured trajectory missing for: `engram-triton-kernel__ZmSGKWj`,
`gemma4-sglang-serving-opt__duCRH2M`. Raw OpenCode logs are listed in the
table.

Scoreboard: **9/20 passed**.

| Task | Reward | Trial | Trajectory/log | Exception |
|---|---:|---|---|---|
| `cute-layout-composition` | 0 | `cute-layout-composition__FQ8ZPrn` | `infra-bench/jobs/opencode-deepseek-v4-flash/cute-layout-composition__FQ8ZPrn/agent/trajectory.json` |  |
| `dwconv3d-occupancy` | 0 | `dwconv3d-occupancy__xAze5au` | `infra-bench/jobs/opencode-deepseek-v4-flash/dwconv3d-occupancy__xAze5au/agent/trajectory.json` |  |
| `engram-triton-kernel` | 0 | `engram-triton-kernel__ZmSGKWj` | `infra-bench/jobs/opencode-deepseek-v4-flash/engram-triton-kernel__ZmSGKWj/agent/opencode.txt` | `AgentTimeoutError` |
| `flydsl-cdna4-preshuffle-gemm` | 0 | `flydsl-cdna4-preshuffle-gemm__9CqjRFF` | `infra-bench/jobs/opencode-deepseek-v4-flash/flydsl-cdna4-preshuffle-gemm__9CqjRFF/agent/trajectory.json` | `AgentTimeoutError` |
| `gemm-fp8-ptpc-quant` | 1 | `gemm-fp8-ptpc-quant__RGK2DHv` | `infra-bench/jobs/opencode-deepseek-v4-flash/gemm-fp8-ptpc-quant__RGK2DHv/agent/trajectory.json` |  |
| `gemma4-gemm-tuning` | 0 | `gemma4-gemm-tuning__Au63iuL` | `infra-bench/jobs/opencode-deepseek-v4-flash/gemma4-gemm-tuning__Au63iuL/agent/trajectory.json` |  |
| `gemma4-sglang-serving-opt` | 0 | `gemma4-sglang-serving-opt__duCRH2M` | `infra-bench/jobs/opencode-deepseek-v4-flash/gemma4-sglang-serving-opt__duCRH2M/agent/opencode.txt` | `AgentTimeoutError` |
| `gluon-a8w8-mfma-att` | 1 | `gluon-a8w8-mfma-att__2PgzZRe` | `infra-bench/jobs/opencode-deepseek-v4-flash/gluon-a8w8-mfma-att__2PgzZRe/agent/trajectory.json` |  |
| `hello-rocm` | 1 | `hello-rocm__QWn7pgy` | `infra-bench/jobs/opencode-deepseek-v4-flash/hello-rocm__QWn7pgy/agent/trajectory.json` |  |
| `hotspot-analysis-torch-profiler` | 0 | `hotspot-analysis-torch-profiler__z9Qnh32` | `infra-bench/jobs/opencode-deepseek-v4-flash/hotspot-analysis-torch-profiler__z9Qnh32/agent/trajectory.json` | `AgentTimeoutError` |
| `llm-fp8-quantize` | 0 | `llm-fp8-quantize__eQckvcG` | `infra-bench/jobs/opencode-deepseek-v4-flash/llm-fp8-quantize__eQckvcG/agent/trajectory.json` | `AgentTimeoutError` |
| `llvm-simple-constant-propagation` | 1 | `llvm-simple-constant-propagation__yQJiWjX` | `infra-bench/jobs/opencode-deepseek-v4-flash/llvm-simple-constant-propagation__yQJiWjX/agent/trajectory.json` |  |
| `mem-bandwidth-bench` | 0 | `mem-bandwidth-bench__Ca5R4kP` | `infra-bench/jobs/opencode-deepseek-v4-flash/mem-bandwidth-bench__Ca5R4kP/agent/trajectory.json` |  |
| `paged-attention-hd256` | 0 | `paged-attention-hd256__UbYBBqh` | `infra-bench/jobs/opencode-deepseek-v4-flash/paged-attention-hd256__UbYBBqh/agent/trajectory.json` |  |
| `pointnet2-hipify` | 1 | `pointnet2-hipify__pt6Kuk9` | `infra-bench/jobs/opencode-deepseek-v4-flash/pointnet2-hipify__pt6Kuk9/agent/trajectory.json` |  |
| `qr-rmsnorm-fusion` | 1 | `qr-rmsnorm-fusion__MEbAZC3` | `infra-bench/jobs/opencode-deepseek-v4-flash/qr-rmsnorm-fusion__MEbAZC3/agent/trajectory.json` |  |
| `sglang-mmmu-ipc-crash` | 1 | `sglang-mmmu-ipc-crash__35XeB4H` | `infra-bench/jobs/opencode-deepseek-v4-flash/sglang-mmmu-ipc-crash__35XeB4H/agent/trajectory.json` |  |
| `sglang-sync-stall` | 1 | `sglang-sync-stall__vDmuEaw` | `infra-bench/jobs/opencode-deepseek-v4-flash/sglang-sync-stall__vDmuEaw/agent/trajectory.json` |  |
| `triton-matmul-tuning` | 1 | `triton-matmul-tuning__Xhf7w3W` | `infra-bench/jobs/opencode-deepseek-v4-flash/triton-matmul-tuning__Xhf7w3W/agent/trajectory.json` |  |
| `vllm-aiter-debug` | 0 | `vllm-aiter-debug__4NcDueG` | `infra-bench/jobs/opencode-deepseek-v4-flash/vllm-aiter-debug__4NcDueG/agent/trajectory.json` | `NonZeroAgentExitCodeError` |

### `Kimi-K2.6` via OpenCode

Command:

```bash
JOB_NAME=opencode-kimi-k2.6 MODEL=Kimi-K2.6 AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' INFRA_PARALLEL=6 INFRABENCH_GPU_COUNT=8 ./run_open_code.sh
```

Result summary:

```text
Trials: 20
Exceptions: 4
Reward 1.0: 11
Reward 0.0: 9
Cost USD: 13.721151
Median agent execution: 5m 49s
Results written to /home/xisun/InfraBench/infra-bench/jobs/opencode-kimi-k2.6/result.json
```

Exception counts: `AgentTimeoutError`=1, `ApiRateLimitError`=1,
`NetworkConnectionError`=1, `NonZeroAgentExitCodeError`=1.

Scoreboard: **11/20 passed**.

| Task | Reward | Trial | Trajectory/log | Exception |
|---|---:|---|---|---|
| `cute-layout-composition` | 0 | `cute-layout-composition__mModf8A` | `infra-bench/jobs/opencode-kimi-k2.6/cute-layout-composition__mModf8A/agent/trajectory.json` |  |
| `dwconv3d-occupancy` | 0 | `dwconv3d-occupancy__uHkLtPT` | `infra-bench/jobs/opencode-kimi-k2.6/dwconv3d-occupancy__uHkLtPT/agent/trajectory.json` |  |
| `engram-triton-kernel` | 1 | `engram-triton-kernel__qCiCDxd` | `infra-bench/jobs/opencode-kimi-k2.6/engram-triton-kernel__qCiCDxd/agent/trajectory.json` |  |
| `flydsl-cdna4-preshuffle-gemm` | 0 | `flydsl-cdna4-preshuffle-gemm__WyV8v3d` | `infra-bench/jobs/opencode-kimi-k2.6/flydsl-cdna4-preshuffle-gemm__WyV8v3d/agent/trajectory.json` |  |
| `gemm-fp8-ptpc-quant` | 0 | `gemm-fp8-ptpc-quant__FxmAY9K` | `infra-bench/jobs/opencode-kimi-k2.6/gemm-fp8-ptpc-quant__FxmAY9K/agent/trajectory.json` |  |
| `gemma4-gemm-tuning` | 0 | `gemma4-gemm-tuning__JTbdkii` | `infra-bench/jobs/opencode-kimi-k2.6/gemma4-gemm-tuning__JTbdkii/agent/trajectory.json` |  |
| `gemma4-sglang-serving-opt` | 0 | `gemma4-sglang-serving-opt__kQgYJuU` | `infra-bench/jobs/opencode-kimi-k2.6/gemma4-sglang-serving-opt__kQgYJuU/agent/trajectory.json` | `AgentTimeoutError` |
| `gluon-a8w8-mfma-att` | 1 | `gluon-a8w8-mfma-att__GTNJKMU` | `infra-bench/jobs/opencode-kimi-k2.6/gluon-a8w8-mfma-att__GTNJKMU/agent/trajectory.json` |  |
| `hello-rocm` | 1 | `hello-rocm__5RiboUn` | `infra-bench/jobs/opencode-kimi-k2.6/hello-rocm__5RiboUn/agent/trajectory.json` |  |
| `hotspot-analysis-torch-profiler` | 1 | `hotspot-analysis-torch-profiler__NLF2bBA` | `infra-bench/jobs/opencode-kimi-k2.6/hotspot-analysis-torch-profiler__NLF2bBA/agent/trajectory.json` | `ApiRateLimitError` |
| `llm-fp8-quantize` | 1 | `llm-fp8-quantize__yVTX8NA` | `infra-bench/jobs/opencode-kimi-k2.6/llm-fp8-quantize__yVTX8NA/agent/trajectory.json` | `NetworkConnectionError` |
| `llvm-simple-constant-propagation` | 1 | `llvm-simple-constant-propagation__gosKKBG` | `infra-bench/jobs/opencode-kimi-k2.6/llvm-simple-constant-propagation__gosKKBG/agent/trajectory.json` |  |
| `mem-bandwidth-bench` | 1 | `mem-bandwidth-bench__a9v3GRF` | `infra-bench/jobs/opencode-kimi-k2.6/mem-bandwidth-bench__a9v3GRF/agent/trajectory.json` |  |
| `paged-attention-hd256` | 0 | `paged-attention-hd256__CY4X7wW` | `infra-bench/jobs/opencode-kimi-k2.6/paged-attention-hd256__CY4X7wW/agent/trajectory.json` |  |
| `pointnet2-hipify` | 1 | `pointnet2-hipify__GxVtDJB` | `infra-bench/jobs/opencode-kimi-k2.6/pointnet2-hipify__GxVtDJB/agent/trajectory.json` |  |
| `qr-rmsnorm-fusion` | 1 | `qr-rmsnorm-fusion__thE269j` | `infra-bench/jobs/opencode-kimi-k2.6/qr-rmsnorm-fusion__thE269j/agent/trajectory.json` |  |
| `sglang-mmmu-ipc-crash` | 1 | `sglang-mmmu-ipc-crash__RD3xwsW` | `infra-bench/jobs/opencode-kimi-k2.6/sglang-mmmu-ipc-crash__RD3xwsW/agent/trajectory.json` |  |
| `sglang-sync-stall` | 0 | `sglang-sync-stall__zx3BRvZ` | `infra-bench/jobs/opencode-kimi-k2.6/sglang-sync-stall__zx3BRvZ/agent/trajectory.json` |  |
| `triton-matmul-tuning` | 1 | `triton-matmul-tuning__kF75Le2` | `infra-bench/jobs/opencode-kimi-k2.6/triton-matmul-tuning__kF75Le2/agent/trajectory.json` |  |
| `vllm-aiter-debug` | 0 | `vllm-aiter-debug__EX7Xzvy` | `infra-bench/jobs/opencode-kimi-k2.6/vllm-aiter-debug__EX7Xzvy/agent/trajectory.json` | `NonZeroAgentExitCodeError` |

### `Qwen3.6-35B-A3B` via OpenCode

Command:

```bash
JOB_NAME=opencode-qwen3.6-35b-a3b MODEL=Qwen3.6-35B-A3B AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' INFRA_PARALLEL=6 INFRABENCH_GPU_COUNT=8 ./run_open_code.sh
```

Result summary:

```text
Trials: 20
Exceptions: 13
Reward 1.0: 2
Reward 0.0: 18
Cost USD: 1.677487
Median agent execution: 50m 22s
Results written to /home/xisun/InfraBench/infra-bench/jobs/opencode-qwen3.6-35b-a3b/result.json
```

Exception counts: `AgentTimeoutError`=10, `NonZeroAgentExitCodeError`=3.

Structured trajectory missing for: `engram-triton-kernel__eRvwvXG`. Raw
OpenCode logs are listed in the table.

Merged result note: the sweep `hello-rocm__98hbAYb` trial timed out despite the
Qwen smoke test passing. The upload candidate replaces that failed sweep trial
with the passing smoke trial `hello-rocm__H7VF7T5` from
`smoke-opencode-qwen3.6-35b-a3b`. The original failed sweep trial is backed up
under
`infra-bench/jobs_bk/opencode-qwen3.6-35b-a3b-hello-rocm-replaced-20260719-000713/`.

Scoreboard: **2/20 passed**.

| Task | Reward | Trial | Trajectory/log | Exception |
|---|---:|---|---|---|
| `cute-layout-composition` | 0 | `cute-layout-composition__csEjXnd` | `infra-bench/jobs/opencode-qwen3.6-35b-a3b/cute-layout-composition__csEjXnd/agent/trajectory.json` | `AgentTimeoutError` |
| `dwconv3d-occupancy` | 0 | `dwconv3d-occupancy__4taoAYo` | `infra-bench/jobs/opencode-qwen3.6-35b-a3b/dwconv3d-occupancy__4taoAYo/agent/trajectory.json` | `AgentTimeoutError` |
| `engram-triton-kernel` | 0 | `engram-triton-kernel__eRvwvXG` | `infra-bench/jobs/opencode-qwen3.6-35b-a3b/engram-triton-kernel__eRvwvXG/agent/opencode.txt` | `AgentTimeoutError` |
| `flydsl-cdna4-preshuffle-gemm` | 0 | `flydsl-cdna4-preshuffle-gemm__8F3uSjr` | `infra-bench/jobs/opencode-qwen3.6-35b-a3b/flydsl-cdna4-preshuffle-gemm__8F3uSjr/agent/trajectory.json` | `AgentTimeoutError` |
| `gemm-fp8-ptpc-quant` | 0 | `gemm-fp8-ptpc-quant__iBtabpp` | `infra-bench/jobs/opencode-qwen3.6-35b-a3b/gemm-fp8-ptpc-quant__iBtabpp/agent/trajectory.json` |  |
| `gemma4-gemm-tuning` | 0 | `gemma4-gemm-tuning__mDm2ErA` | `infra-bench/jobs/opencode-qwen3.6-35b-a3b/gemma4-gemm-tuning__mDm2ErA/agent/trajectory.json` |  |
| `gemma4-sglang-serving-opt` | 0 | `gemma4-sglang-serving-opt__th42WAz` | `infra-bench/jobs/opencode-qwen3.6-35b-a3b/gemma4-sglang-serving-opt__th42WAz/agent/trajectory.json` | `AgentTimeoutError` |
| `gluon-a8w8-mfma-att` | 0 | `gluon-a8w8-mfma-att__HatYJXB` | `infra-bench/jobs/opencode-qwen3.6-35b-a3b/gluon-a8w8-mfma-att__HatYJXB/agent/trajectory.json` | `AgentTimeoutError` |
| `hello-rocm` | 1 | `hello-rocm__H7VF7T5` | `infra-bench/jobs/opencode-qwen3.6-35b-a3b/hello-rocm__H7VF7T5/agent/trajectory.json` |  |
| `hotspot-analysis-torch-profiler` | 0 | `hotspot-analysis-torch-profiler__Y5LjoiQ` | `infra-bench/jobs/opencode-qwen3.6-35b-a3b/hotspot-analysis-torch-profiler__Y5LjoiQ/agent/trajectory.json` | `NonZeroAgentExitCodeError` |
| `llm-fp8-quantize` | 0 | `llm-fp8-quantize__X4BHBiU` | `infra-bench/jobs/opencode-qwen3.6-35b-a3b/llm-fp8-quantize__X4BHBiU/agent/trajectory.json` | `AgentTimeoutError` |
| `llvm-simple-constant-propagation` | 0 | `llvm-simple-constant-propagation__DnkhHSe` | `infra-bench/jobs/opencode-qwen3.6-35b-a3b/llvm-simple-constant-propagation__DnkhHSe/agent/trajectory.json` | `AgentTimeoutError` |
| `mem-bandwidth-bench` | 0 | `mem-bandwidth-bench__tiDXADg` | `infra-bench/jobs/opencode-qwen3.6-35b-a3b/mem-bandwidth-bench__tiDXADg/agent/trajectory.json` |  |
| `paged-attention-hd256` | 0 | `paged-attention-hd256__yx3yMDi` | `infra-bench/jobs/opencode-qwen3.6-35b-a3b/paged-attention-hd256__yx3yMDi/agent/trajectory.json` |  |
| `pointnet2-hipify` | 1 | `pointnet2-hipify__B8xzj7A` | `infra-bench/jobs/opencode-qwen3.6-35b-a3b/pointnet2-hipify__B8xzj7A/agent/trajectory.json` | `AgentTimeoutError` |
| `qr-rmsnorm-fusion` | 0 | `qr-rmsnorm-fusion__RPPqLz6` | `infra-bench/jobs/opencode-qwen3.6-35b-a3b/qr-rmsnorm-fusion__RPPqLz6/agent/trajectory.json` |  |
| `sglang-mmmu-ipc-crash` | 0 | `sglang-mmmu-ipc-crash__iB9KjrM` | `infra-bench/jobs/opencode-qwen3.6-35b-a3b/sglang-mmmu-ipc-crash__iB9KjrM/agent/trajectory.json` | `AgentTimeoutError` |
| `sglang-sync-stall` | 0 | `sglang-sync-stall__HbN7fC6` | `infra-bench/jobs/opencode-qwen3.6-35b-a3b/sglang-sync-stall__HbN7fC6/agent/trajectory.json` | `NonZeroAgentExitCodeError` |
| `triton-matmul-tuning` | 0 | `triton-matmul-tuning__uWXc5qM` | `infra-bench/jobs/opencode-qwen3.6-35b-a3b/triton-matmul-tuning__uWXc5qM/agent/trajectory.json` |  |
| `vllm-aiter-debug` | 0 | `vllm-aiter-debug__mNnVwwT` | `infra-bench/jobs/opencode-qwen3.6-35b-a3b/vllm-aiter-debug__mNnVwwT/agent/trajectory.json` | `NonZeroAgentExitCodeError` |

### `gemini-3.5-flash` via OpenCode

Command:

```bash
JOB_NAME=opencode-gemini-3.5-flash MODEL=gemini-3.5-flash AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' INFRA_PARALLEL=6 INFRABENCH_GPU_COUNT=8 ./run_open_code.sh
```

Result summary:

```text
Trials: 20
Exceptions: 5
Reward 1.0: 14
Reward 0.0: 6
Cost USD: 173.511468
Median agent execution: 7m 2s
Results written to /home/xisun/InfraBench/infra-bench/jobs/opencode-gemini-3.5-flash/result.json
```

Exception counts: `AgentTimeoutError`=1, `ApiRateLimitError`=2,
`NonZeroAgentExitCodeError`=2.

Scoreboard: **14/20 passed**.

| Task | Reward | Trial | Trajectory/log | Exception |
|---|---:|---|---|---|
| `cute-layout-composition` | 0 | `cute-layout-composition__8kJpL3H` | `infra-bench/jobs/opencode-gemini-3.5-flash/cute-layout-composition__8kJpL3H/agent/trajectory.json` |  |
| `dwconv3d-occupancy` | 1 | `dwconv3d-occupancy__R4NEAxH` | `infra-bench/jobs/opencode-gemini-3.5-flash/dwconv3d-occupancy__R4NEAxH/agent/trajectory.json` |  |
| `engram-triton-kernel` | 1 | `engram-triton-kernel__UJ6B4ej` | `infra-bench/jobs/opencode-gemini-3.5-flash/engram-triton-kernel__UJ6B4ej/agent/trajectory.json` |  |
| `flydsl-cdna4-preshuffle-gemm` | 1 | `flydsl-cdna4-preshuffle-gemm__AkiY2xT` | `infra-bench/jobs/opencode-gemini-3.5-flash/flydsl-cdna4-preshuffle-gemm__AkiY2xT/agent/trajectory.json` |  |
| `gemm-fp8-ptpc-quant` | 1 | `gemm-fp8-ptpc-quant__YwZAmY2` | `infra-bench/jobs/opencode-gemini-3.5-flash/gemm-fp8-ptpc-quant__YwZAmY2/agent/trajectory.json` |  |
| `gemma4-gemm-tuning` | 1 | `gemma4-gemm-tuning__4aXMtW8` | `infra-bench/jobs/opencode-gemini-3.5-flash/gemma4-gemm-tuning__4aXMtW8/agent/trajectory.json` |  |
| `gemma4-sglang-serving-opt` | 0 | `gemma4-sglang-serving-opt__F4SaJik` | `infra-bench/jobs/opencode-gemini-3.5-flash/gemma4-sglang-serving-opt__F4SaJik/agent/trajectory.json` | `AgentTimeoutError` |
| `gluon-a8w8-mfma-att` | 1 | `gluon-a8w8-mfma-att__KxNWYWZ` | `infra-bench/jobs/opencode-gemini-3.5-flash/gluon-a8w8-mfma-att__KxNWYWZ/agent/trajectory.json` |  |
| `hello-rocm` | 1 | `hello-rocm__VJDwXXF` | `infra-bench/jobs/opencode-gemini-3.5-flash/hello-rocm__VJDwXXF/agent/trajectory.json` |  |
| `hotspot-analysis-torch-profiler` | 1 | `hotspot-analysis-torch-profiler__QDB7ASb` | `infra-bench/jobs/opencode-gemini-3.5-flash/hotspot-analysis-torch-profiler__QDB7ASb/agent/trajectory.json` | `ApiRateLimitError` |
| `llm-fp8-quantize` | 1 | `llm-fp8-quantize__bmUPqtH` | `infra-bench/jobs/opencode-gemini-3.5-flash/llm-fp8-quantize__bmUPqtH/agent/trajectory.json` | `ApiRateLimitError` |
| `llvm-simple-constant-propagation` | 0 | `llvm-simple-constant-propagation__vm56NAK` | `infra-bench/jobs/opencode-gemini-3.5-flash/llvm-simple-constant-propagation__vm56NAK/agent/trajectory.json` |  |
| `mem-bandwidth-bench` | 1 | `mem-bandwidth-bench__JR58crW` | `infra-bench/jobs/opencode-gemini-3.5-flash/mem-bandwidth-bench__JR58crW/agent/trajectory.json` |  |
| `paged-attention-hd256` | 1 | `paged-attention-hd256__KvRdrw8` | `infra-bench/jobs/opencode-gemini-3.5-flash/paged-attention-hd256__KvRdrw8/agent/trajectory.json` |  |
| `pointnet2-hipify` | 1 | `pointnet2-hipify__5ai6Xao` | `infra-bench/jobs/opencode-gemini-3.5-flash/pointnet2-hipify__5ai6Xao/agent/trajectory.json` |  |
| `qr-rmsnorm-fusion` | 1 | `qr-rmsnorm-fusion__snsRBfh` | `infra-bench/jobs/opencode-gemini-3.5-flash/qr-rmsnorm-fusion__snsRBfh/agent/trajectory.json` |  |
| `sglang-mmmu-ipc-crash` | 0 | `sglang-mmmu-ipc-crash__aZ5eLik` | `infra-bench/jobs/opencode-gemini-3.5-flash/sglang-mmmu-ipc-crash__aZ5eLik/agent/trajectory.json` | `NonZeroAgentExitCodeError` |
| `sglang-sync-stall` | 0 | `sglang-sync-stall__Y4NJJke` | `infra-bench/jobs/opencode-gemini-3.5-flash/sglang-sync-stall__Y4NJJke/agent/trajectory.json` |  |
| `triton-matmul-tuning` | 1 | `triton-matmul-tuning__3BFJHEJ` | `infra-bench/jobs/opencode-gemini-3.5-flash/triton-matmul-tuning__3BFJHEJ/agent/trajectory.json` |  |
| `vllm-aiter-debug` | 0 | `vllm-aiter-debug__qmeHA6r` | `infra-bench/jobs/opencode-gemini-3.5-flash/vllm-aiter-debug__qmeHA6r/agent/trajectory.json` | `NonZeroAgentExitCodeError` |

### `Gemma-4-31B` via OpenCode

Command:

```bash
JOB_NAME=opencode-gemma-4-31b MODEL=Gemma-4-31B AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' INFRA_PARALLEL=6 INFRABENCH_GPU_COUNT=8 ./run_open_code.sh
```

Result summary:

```text
Trials: 20
Exceptions: 5
Reward 1.0: 1
Reward 0.0: 19
Cost USD: 0.409919
Median agent execution: 26m 12s
Results written to /home/xisun/InfraBench/infra-bench/jobs/opencode-gemma-4-31b/result.json
```

Exception counts: `AgentTimeoutError`=3, `NonZeroAgentExitCodeError`=2.

Merged result note: the sweep `hello-rocm__Rc3edLD` trial timed out despite the
Gemma smoke test passing. The upload candidate replaces that failed sweep trial
with the passing smoke trial `hello-rocm__RJsvaKs` from
`smoke-opencode-gemma-4-31b`. The original failed sweep trial is backed up under
`infra-bench/jobs_bk/opencode-gemma-4-31b-hello-rocm-replaced-20260719-000312/`.

Scoreboard: **1/20 passed**.

| Task | Reward | Trial | Trajectory/log | Exception |
|---|---:|---|---|---|
| `cute-layout-composition` | 0 | `cute-layout-composition__DwWB8T7` | `infra-bench/jobs/opencode-gemma-4-31b/cute-layout-composition__DwWB8T7/agent/trajectory.json` | `AgentTimeoutError` |
| `dwconv3d-occupancy` | 0 | `dwconv3d-occupancy__SppsrPk` | `infra-bench/jobs/opencode-gemma-4-31b/dwconv3d-occupancy__SppsrPk/agent/trajectory.json` |  |
| `engram-triton-kernel` | 0 | `engram-triton-kernel__ksXbsFx` | `infra-bench/jobs/opencode-gemma-4-31b/engram-triton-kernel__ksXbsFx/agent/trajectory.json` |  |
| `flydsl-cdna4-preshuffle-gemm` | 0 | `flydsl-cdna4-preshuffle-gemm__QaLVEuc` | `infra-bench/jobs/opencode-gemma-4-31b/flydsl-cdna4-preshuffle-gemm__QaLVEuc/agent/trajectory.json` |  |
| `gemm-fp8-ptpc-quant` | 0 | `gemm-fp8-ptpc-quant__2SF5PzE` | `infra-bench/jobs/opencode-gemma-4-31b/gemm-fp8-ptpc-quant__2SF5PzE/agent/trajectory.json` | `NonZeroAgentExitCodeError` |
| `gemma4-gemm-tuning` | 0 | `gemma4-gemm-tuning__6pfECc6` | `infra-bench/jobs/opencode-gemma-4-31b/gemma4-gemm-tuning__6pfECc6/agent/trajectory.json` |  |
| `gemma4-sglang-serving-opt` | 0 | `gemma4-sglang-serving-opt__HVfhPb9` | `infra-bench/jobs/opencode-gemma-4-31b/gemma4-sglang-serving-opt__HVfhPb9/agent/trajectory.json` |  |
| `gluon-a8w8-mfma-att` | 0 | `gluon-a8w8-mfma-att__Wp5WWmC` | `infra-bench/jobs/opencode-gemma-4-31b/gluon-a8w8-mfma-att__Wp5WWmC/agent/trajectory.json` | `AgentTimeoutError` |
| `hello-rocm` | 1 | `hello-rocm__RJsvaKs` | `infra-bench/jobs/opencode-gemma-4-31b/hello-rocm__RJsvaKs/agent/trajectory.json` |  |
| `hotspot-analysis-torch-profiler` | 0 | `hotspot-analysis-torch-profiler__JYxfUrs` | `infra-bench/jobs/opencode-gemma-4-31b/hotspot-analysis-torch-profiler__JYxfUrs/agent/trajectory.json` |  |
| `llm-fp8-quantize` | 0 | `llm-fp8-quantize__NfRVLBA` | `infra-bench/jobs/opencode-gemma-4-31b/llm-fp8-quantize__NfRVLBA/agent/trajectory.json` |  |
| `llvm-simple-constant-propagation` | 0 | `llvm-simple-constant-propagation__DZhk8GB` | `infra-bench/jobs/opencode-gemma-4-31b/llvm-simple-constant-propagation__DZhk8GB/agent/trajectory.json` | `AgentTimeoutError` |
| `mem-bandwidth-bench` | 0 | `mem-bandwidth-bench__iFiV9gD` | `infra-bench/jobs/opencode-gemma-4-31b/mem-bandwidth-bench__iFiV9gD/agent/trajectory.json` |  |
| `paged-attention-hd256` | 0 | `paged-attention-hd256__rrVeeQs` | `infra-bench/jobs/opencode-gemma-4-31b/paged-attention-hd256__rrVeeQs/agent/trajectory.json` |  |
| `pointnet2-hipify` | 0 | `pointnet2-hipify__zagsKW3` | `infra-bench/jobs/opencode-gemma-4-31b/pointnet2-hipify__zagsKW3/agent/trajectory.json` |  |
| `qr-rmsnorm-fusion` | 0 | `qr-rmsnorm-fusion__SjxwDzL` | `infra-bench/jobs/opencode-gemma-4-31b/qr-rmsnorm-fusion__SjxwDzL/agent/trajectory.json` | `NonZeroAgentExitCodeError` |
| `sglang-mmmu-ipc-crash` | 0 | `sglang-mmmu-ipc-crash__fmHwY95` | `infra-bench/jobs/opencode-gemma-4-31b/sglang-mmmu-ipc-crash__fmHwY95/agent/trajectory.json` |  |
| `sglang-sync-stall` | 0 | `sglang-sync-stall__AkGAV6q` | `infra-bench/jobs/opencode-gemma-4-31b/sglang-sync-stall__AkGAV6q/agent/trajectory.json` |  |
| `triton-matmul-tuning` | 0 | `triton-matmul-tuning__E2tNGCe` | `infra-bench/jobs/opencode-gemma-4-31b/triton-matmul-tuning__E2tNGCe/agent/trajectory.json` |  |
| `vllm-aiter-debug` | 0 | `vllm-aiter-debug__VswMsDN` | `infra-bench/jobs/opencode-gemma-4-31b/vllm-aiter-debug__VswMsDN/agent/trajectory.json` |  |

### `claude-opus-4.8` via Claude Code

Smoke command:

```bash
JOB_NAME=smoke-claude-opus-4.8 MODEL=claude-opus-4.8 ./run_claude_code.sh -i hello-rocm
```

Smoke result: **1/1 passed**; cost `2.436881` USD; trajectory
`infra-bench/jobs/smoke-claude-opus-4.8/hello-rocm__EzMHYco/agent/trajectory.json`.

Full command:

```bash
JOB_NAME=claude-opus-4.8 MODEL=claude-opus-4.8 INFRA_PARALLEL=6 INFRABENCH_GPU_COUNT=8 ./run_claude_code.sh
```

Result summary:

```text
Trials: 20
Exceptions: 4
Reward 1.0: 16
Reward 0.0: 4
Cost USD: 69.782510
Median agent execution: 5m 15s
Results written to /home/xisun/InfraBench/infra-bench/jobs/claude-opus-4.8/result.json
```

Exception counts: `NonZeroAgentExitCodeError`=2, `AgentTimeoutError`=1,
`UnknownApiError`=1.

All 20 trials have structured `agent/trajectory.json` files. Note that Harbor
counts agent exceptions independently from verifier rewards; for example,
`llm-fp8-quantize__qaVH9ZU` hit the 5400-second agent timeout but still received
reward 1 after the verifier ran against the produced `/app/fp8_model` artifact.

Scoreboard: **16/20 passed**.

| Task | Reward | Trial | Trajectory/log | Exception |
|---|---:|---|---|---|
| `cute-layout-composition` | 0 | `cute-layout-composition__VQJZjPF` | `infra-bench/jobs/claude-opus-4.8/cute-layout-composition__VQJZjPF/agent/trajectory.json` |  |
| `dwconv3d-occupancy` | 1 | `dwconv3d-occupancy__Ntoa7pA` | `infra-bench/jobs/claude-opus-4.8/dwconv3d-occupancy__Ntoa7pA/agent/trajectory.json` |  |
| `engram-triton-kernel` | 1 | `engram-triton-kernel__PjzN7Lm` | `infra-bench/jobs/claude-opus-4.8/engram-triton-kernel__PjzN7Lm/agent/trajectory.json` |  |
| `flydsl-cdna4-preshuffle-gemm` | 1 | `flydsl-cdna4-preshuffle-gemm__vb5zUvX` | `infra-bench/jobs/claude-opus-4.8/flydsl-cdna4-preshuffle-gemm__vb5zUvX/agent/trajectory.json` |  |
| `gemm-fp8-ptpc-quant` | 1 | `gemm-fp8-ptpc-quant__paKWs88` | `infra-bench/jobs/claude-opus-4.8/gemm-fp8-ptpc-quant__paKWs88/agent/trajectory.json` |  |
| `gemma4-gemm-tuning` | 0 | `gemma4-gemm-tuning__5bswW4p` | `infra-bench/jobs/claude-opus-4.8/gemma4-gemm-tuning__5bswW4p/agent/trajectory.json` |  |
| `gemma4-sglang-serving-opt` | 0 | `gemma4-sglang-serving-opt__HBZYom2` | `infra-bench/jobs/claude-opus-4.8/gemma4-sglang-serving-opt__HBZYom2/agent/trajectory.json` | `NonZeroAgentExitCodeError` |
| `gluon-a8w8-mfma-att` | 1 | `gluon-a8w8-mfma-att__8YKEQe4` | `infra-bench/jobs/claude-opus-4.8/gluon-a8w8-mfma-att__8YKEQe4/agent/trajectory.json` |  |
| `hello-rocm` | 1 | `hello-rocm__7E86tMm` | `infra-bench/jobs/claude-opus-4.8/hello-rocm__7E86tMm/agent/trajectory.json` |  |
| `hotspot-analysis-torch-profiler` | 1 | `hotspot-analysis-torch-profiler__GiEGsG4` | `infra-bench/jobs/claude-opus-4.8/hotspot-analysis-torch-profiler__GiEGsG4/agent/trajectory.json` |  |
| `llm-fp8-quantize` | 1 | `llm-fp8-quantize__qaVH9ZU` | `infra-bench/jobs/claude-opus-4.8/llm-fp8-quantize__qaVH9ZU/agent/trajectory.json` | `AgentTimeoutError` |
| `llvm-simple-constant-propagation` | 1 | `llvm-simple-constant-propagation__BhYdKvv` | `infra-bench/jobs/claude-opus-4.8/llvm-simple-constant-propagation__BhYdKvv/agent/trajectory.json` |  |
| `mem-bandwidth-bench` | 1 | `mem-bandwidth-bench__TzU8UAc` | `infra-bench/jobs/claude-opus-4.8/mem-bandwidth-bench__TzU8UAc/agent/trajectory.json` |  |
| `paged-attention-hd256` | 0 | `paged-attention-hd256__zMGZZXY` | `infra-bench/jobs/claude-opus-4.8/paged-attention-hd256__zMGZZXY/agent/trajectory.json` | `UnknownApiError` |
| `pointnet2-hipify` | 1 | `pointnet2-hipify__xcTG35X` | `infra-bench/jobs/claude-opus-4.8/pointnet2-hipify__xcTG35X/agent/trajectory.json` |  |
| `qr-rmsnorm-fusion` | 1 | `qr-rmsnorm-fusion__iXeQ3xz` | `infra-bench/jobs/claude-opus-4.8/qr-rmsnorm-fusion__iXeQ3xz/agent/trajectory.json` |  |
| `sglang-mmmu-ipc-crash` | 1 | `sglang-mmmu-ipc-crash__gYS9mgu` | `infra-bench/jobs/claude-opus-4.8/sglang-mmmu-ipc-crash__gYS9mgu/agent/trajectory.json` |  |
| `sglang-sync-stall` | 1 | `sglang-sync-stall__aPhK7mY` | `infra-bench/jobs/claude-opus-4.8/sglang-sync-stall__aPhK7mY/agent/trajectory.json` |  |
| `triton-matmul-tuning` | 1 | `triton-matmul-tuning__ALSXqwS` | `infra-bench/jobs/claude-opus-4.8/triton-matmul-tuning__ALSXqwS/agent/trajectory.json` |  |
| `vllm-aiter-debug` | 1 | `vllm-aiter-debug__jbg2Tsx` | `infra-bench/jobs/claude-opus-4.8/vllm-aiter-debug__jbg2Tsx/agent/trajectory.json` | `NonZeroAgentExitCodeError` |

### Round 2 Exclusions

`Kimi-K2.7-Code` was removed from the active test plan on 2026-07-18 because
its `hello-rocm` smoke test routed successfully but produced unusable output and
failed to write `/app/gpu_report.json`. It was replaced by `Kimi-K2.6`, whose
smoke passed and whose full sweep is recorded above.

`Grok-4.3` was removed from the active test plan on 2026-07-18. The dashboard
showed the model as operational, but smoke tests against the configured AMD
Unified gateway route failed before agent execution: Chat Completions returned
`Deployment of "Grok-4.3" for "ChatCompletions" is not found`, and the Responses
adapter returned `Deployment of "Grok-4.3" for "Responses" is not found`.

## Round 3 Results

Run date: 2026-07-19

Round 3 adds `gpt-5.6-terra` through the Codex runner. The smoke and full-sweep
jobs are saved under `infra-bench/jobs/`.

### Round 3 Smoke Tests

| Agent | Model | Job | Reward | Cost USD | Run log | Trajectory/log |
|---|---|---|---:|---:|---|---|
| codex | `gpt-5.6-terra` | `smoke-codex-gpt-5.6-terra` | 1/1 | 0.032377 | `infra-bench/jobs/smoke-codex-gpt-5.6-terra/run.log` | `infra-bench/jobs/smoke-codex-gpt-5.6-terra/hello-rocm__harvpHh/agent/trajectory.json` |

### Round 3 Aggregate Scoreboard

| Agent | Model | Job | Pass rate | Cost USD | Median agent execution | Exceptions | Structured trajectories missing |
|---|---|---|---:|---:|---:|---:|---:|
| codex | `gpt-5.6-terra` | `codex-gpt-5.6-terra` | 18/20 | 13.849469 | 6m 59s | 0 | 0 |

Metadata note: before recording the job as upload-ready, the Terra smoke and
full-sweep job `config.json`, `lock.json`, and nested trial `result.json`
agent names were normalized from `agents.amd_codex:AmdCodex` to `codex`, matching
the prior Codex upload directories. The pre-patch artifacts were backed up under
`infra-bench/jobs_bk/codex-gpt-5.6-terra-agent-name-fix-20260719-015503/`.

### `gpt-5.6-terra` via Codex

Smoke command:

```bash
JOB_NAME=smoke-codex-gpt-5.6-terra MODEL=gpt-5.6-terra ./run_codex.sh -i hello-rocm
```

Smoke result: **1/1 passed**; cost `0.032377` USD; trajectory
`infra-bench/jobs/smoke-codex-gpt-5.6-terra/hello-rocm__harvpHh/agent/trajectory.json`.

Full command:

```bash
JOB_NAME=codex-gpt-5.6-terra MODEL=gpt-5.6-terra INFRA_PARALLEL=6 INFRABENCH_GPU_COUNT=8 ./run_codex.sh
```

Result summary:

```text
Trials: 20
Exceptions: 0
Reward 1.0: 18
Reward 0.0: 2
Cost USD: 13.849469
Median agent execution: 6m 59s
Input tokens: 27675788
Cache tokens: 26089216
Output tokens: 224049
Results written to /home/xisun/InfraBench/infra-bench/jobs/codex-gpt-5.6-terra/result.json
Run log: /home/xisun/InfraBench/infra-bench/jobs/codex-gpt-5.6-terra/run.log
```

Failure notes:

- `gemma4-sglang-serving-opt__SvitwCt` reached the verifier, but the agent
  server was not healthy. The verifier reported `server_not_healthy` after an
  `UnboundLocalError: local variable 'shuffle_weight' referenced before
  assignment`.
- `paged-attention-hd256__zQbKkJ4` reached the verifier and failed correctness:
  `correct_kv257`, `correct_kv2048`, and `perf_shape_correct`.

All 20 trials have structured `agent/trajectory.json` files. Harbor reported no
agent exceptions for this sweep.

Scoreboard: **18/20 passed**.

| Task | Reward | Trial | Trajectory/log | Exception |
|---|---:|---|---|---|
| `cute-layout-composition` | 1 | `cute-layout-composition__KSmw3C8` | `infra-bench/jobs/codex-gpt-5.6-terra/cute-layout-composition__KSmw3C8/agent/trajectory.json` |  |
| `dwconv3d-occupancy` | 1 | `dwconv3d-occupancy__niv8Ubv` | `infra-bench/jobs/codex-gpt-5.6-terra/dwconv3d-occupancy__niv8Ubv/agent/trajectory.json` |  |
| `engram-triton-kernel` | 1 | `engram-triton-kernel__HR3yugo` | `infra-bench/jobs/codex-gpt-5.6-terra/engram-triton-kernel__HR3yugo/agent/trajectory.json` |  |
| `flydsl-cdna4-preshuffle-gemm` | 1 | `flydsl-cdna4-preshuffle-gemm__hKAfqKq` | `infra-bench/jobs/codex-gpt-5.6-terra/flydsl-cdna4-preshuffle-gemm__hKAfqKq/agent/trajectory.json` |  |
| `gemm-fp8-ptpc-quant` | 1 | `gemm-fp8-ptpc-quant__BQDmF48` | `infra-bench/jobs/codex-gpt-5.6-terra/gemm-fp8-ptpc-quant__BQDmF48/agent/trajectory.json` |  |
| `gemma4-gemm-tuning` | 1 | `gemma4-gemm-tuning__7jyLgbX` | `infra-bench/jobs/codex-gpt-5.6-terra/gemma4-gemm-tuning__7jyLgbX/agent/trajectory.json` |  |
| `gemma4-sglang-serving-opt` | 0 | `gemma4-sglang-serving-opt__SvitwCt` | `infra-bench/jobs/codex-gpt-5.6-terra/gemma4-sglang-serving-opt__SvitwCt/agent/trajectory.json` |  |
| `gluon-a8w8-mfma-att` | 1 | `gluon-a8w8-mfma-att__ss5Dt8L` | `infra-bench/jobs/codex-gpt-5.6-terra/gluon-a8w8-mfma-att__ss5Dt8L/agent/trajectory.json` |  |
| `hello-rocm` | 1 | `hello-rocm__wsSDFxX` | `infra-bench/jobs/codex-gpt-5.6-terra/hello-rocm__wsSDFxX/agent/trajectory.json` |  |
| `hotspot-analysis-torch-profiler` | 1 | `hotspot-analysis-torch-profiler__EXDhTj2` | `infra-bench/jobs/codex-gpt-5.6-terra/hotspot-analysis-torch-profiler__EXDhTj2/agent/trajectory.json` |  |
| `llm-fp8-quantize` | 1 | `llm-fp8-quantize__o74Xm39` | `infra-bench/jobs/codex-gpt-5.6-terra/llm-fp8-quantize__o74Xm39/agent/trajectory.json` |  |
| `llvm-simple-constant-propagation` | 1 | `llvm-simple-constant-propagation__Kk7jKHq` | `infra-bench/jobs/codex-gpt-5.6-terra/llvm-simple-constant-propagation__Kk7jKHq/agent/trajectory.json` |  |
| `mem-bandwidth-bench` | 1 | `mem-bandwidth-bench__mT9vTKs` | `infra-bench/jobs/codex-gpt-5.6-terra/mem-bandwidth-bench__mT9vTKs/agent/trajectory.json` |  |
| `paged-attention-hd256` | 0 | `paged-attention-hd256__zQbKkJ4` | `infra-bench/jobs/codex-gpt-5.6-terra/paged-attention-hd256__zQbKkJ4/agent/trajectory.json` |  |
| `pointnet2-hipify` | 1 | `pointnet2-hipify__6RBopvb` | `infra-bench/jobs/codex-gpt-5.6-terra/pointnet2-hipify__6RBopvb/agent/trajectory.json` |  |
| `qr-rmsnorm-fusion` | 1 | `qr-rmsnorm-fusion__eLviek3` | `infra-bench/jobs/codex-gpt-5.6-terra/qr-rmsnorm-fusion__eLviek3/agent/trajectory.json` |  |
| `sglang-mmmu-ipc-crash` | 1 | `sglang-mmmu-ipc-crash__HApnfxE` | `infra-bench/jobs/codex-gpt-5.6-terra/sglang-mmmu-ipc-crash__HApnfxE/agent/trajectory.json` |  |
| `sglang-sync-stall` | 1 | `sglang-sync-stall__r8DWsuB` | `infra-bench/jobs/codex-gpt-5.6-terra/sglang-sync-stall__r8DWsuB/agent/trajectory.json` |  |
| `triton-matmul-tuning` | 1 | `triton-matmul-tuning__vcF53dr` | `infra-bench/jobs/codex-gpt-5.6-terra/triton-matmul-tuning__vcF53dr/agent/trajectory.json` |  |
| `vllm-aiter-debug` | 1 | `vllm-aiter-debug__nc5paDp` | `infra-bench/jobs/codex-gpt-5.6-terra/vllm-aiter-debug__nc5paDp/agent/trajectory.json` |  |

## Round 4 Results

Run date: 2026-07-19

Round 4 adds `GLM-5.2-FP8` through OpenCode against an on-prem SGLang server at
`http://10.145.64.81:30000/v1`, using provider id `onprem`.

Endpoint sanity: `GET /v1/models` on the on-prem server returned
`/models/GLM-5.2-FP8`, and direct `chat/completions` calls accepted both
`GLM-5.2-FP8` and `/models/GLM-5.2-FP8` as model ids. In this shell,
`glm5.2-fp8-sgl/run_sgl_ping.sh` did not run because `sgl-eval` was not on
`PATH`.

After restarting the on-prem server with `--reasoning-parser glm45
--tool-call-parser glm47`, the GLM smoke produced structured OpenCode
`tool_use` events and passed. The first failed smoke is retained below as a
parser-configuration diagnostic.

### Round 4 Smoke Tests

| Agent | Model | Job | Reward | Cost USD | Run log | Trajectory/log |
|---|---|---|---:|---:|---|---|
| opencode | `GLM-5.2-FP8` | `smoke-opencode-glm-5.2-fp8-onprem` | 0/1 | 0.010696 | `infra-bench/jobs/smoke-opencode-glm-5.2-fp8-onprem/run.log` | `infra-bench/jobs/smoke-opencode-glm-5.2-fp8-onprem/hello-rocm__akDTut6/agent/trajectory.json` |
| opencode | `GLM-5.2-FP8` | `smoke-opencode-glm-5.2-fp8-onprem-rerun` | 1/1 | 0.032062 | `infra-bench/jobs/smoke-opencode-glm-5.2-fp8-onprem-rerun/run.log` | `infra-bench/jobs/smoke-opencode-glm-5.2-fp8-onprem-rerun/hello-rocm__dyvdR6s/agent/trajectory.json` |

### `GLM-5.2-FP8` via OpenCode On-Prem

Smoke command:

```bash
JOB_NAME=smoke-opencode-glm-5.2-fp8-onprem \
  MODEL=GLM-5.2-FP8 \
  AMD_OPENCODE_PROVIDER=onprem \
  AMD_CODEX_BASE_URL=http://10.145.64.81:30000/v1 \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' \
  ./run_open_code.sh -i hello-rocm
```

First smoke result summary:

```text
Trials: 1
Exceptions: 0
Reward 1.0: 0
Reward 0.0: 1
Cost USD: 0.010696
Input tokens: 7282
Cache tokens: 0
Output tokens: 114
Results written to /home/xisun/InfraBench/infra-bench/jobs/smoke-opencode-glm-5.2-fp8-onprem/result.json
Run log: /home/xisun/InfraBench/infra-bench/jobs/smoke-opencode-glm-5.2-fp8-onprem/run.log
```

Failure note: this was not a network or authentication failure. OpenCode
received a plain text response containing a literal
`<tool_call>bash ...</tool_call>` block, so no tool was executed and the task
never wrote `/app/gpu_report.json`. The verifier failed all four `hello-rocm`
checks because `/app/gpu_report.json` was missing. SGLang's GLM-5.2 guidance says
to serve with `--reasoning-parser glm45 --tool-call-parser glm47`; the `glm47`
tool-call parser is required for GLM-5.2's newer `<tool_call>...<arg_key>...`
format. Restart the on-prem server with those parser flags, then rerun this
smoke before starting the full `opencode-glm-5.2-fp8-onprem` sweep.

Rerun smoke command after parser fix:

```bash
JOB_NAME=smoke-opencode-glm-5.2-fp8-onprem-rerun \
  MODEL=GLM-5.2-FP8 \
  AMD_OPENCODE_PROVIDER=onprem \
  AMD_CODEX_BASE_URL=http://10.145.64.81:30000/v1 \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' \
  ./run_open_code.sh -i hello-rocm
```

Rerun result summary:

```text
Trials: 1
Exceptions: 0
Reward 1.0: 1
Reward 0.0: 0
Cost USD: 0.032062
Input tokens: 22295
Cache tokens: 0
Output tokens: 193
Results written to /home/xisun/InfraBench/infra-bench/jobs/smoke-opencode-glm-5.2-fp8-onprem-rerun/result.json
Run log: /home/xisun/InfraBench/infra-bench/jobs/smoke-opencode-glm-5.2-fp8-onprem-rerun/run.log
```

Rerun note: the rerun trajectory contains structured OpenCode `tool_use` events
for `bash` and `read`, and the verifier passed all four `hello-rocm` checks.

Per-task trajectory:

| Task | Reward | Trial | Trajectory/log | Exception |
|---|---:|---|---|---|
| `hello-rocm` | 0 | `hello-rocm__akDTut6` | `infra-bench/jobs/smoke-opencode-glm-5.2-fp8-onprem/hello-rocm__akDTut6/agent/trajectory.json` |  |
| `hello-rocm` | 1 | `hello-rocm__dyvdR6s` | `infra-bench/jobs/smoke-opencode-glm-5.2-fp8-onprem-rerun/hello-rocm__dyvdR6s/agent/trajectory.json` |  |

Full sweep command:

```bash
JOB_NAME=opencode-glm-5.2-fp8-onprem MODEL=GLM-5.2-FP8 \
  AMD_OPENCODE_PROVIDER=onprem \
  AMD_CODEX_BASE_URL=http://10.145.64.81:30000/v1 \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' \
  INFRA_PARALLEL=4 INFRABENCH_GPU_COUNT=8 ./run_open_code.sh
```

Operational note: the first full-sweep attempt used `INFRA_PARALLEL=6` and was
aborted after the host filled its disk (`No space left on device`). That partial
invalid job was moved to
`infra-bench/jobs_bk/opencode-glm-5.2-fp8-onprem-diskfull-20260719-051434/`.
After Docker cleanup, the final upload candidate was rerun with
`INFRA_PARALLEL=4`. During the final run, the on-prem SGLang server stopped
serving connections once; after it was restarted, the waiting OpenCode trials
resumed and the suite completed.

Full result summary:

```text
Trials: 20
Exceptions: 5
Reward 1.0: 15
Reward 0.0: 5
Mean reward: 0.750
Total runtime: 2h 55m 42s
Cost USD: 88.395059
Median agent execution: 25m 26s
Input tokens: 60405209
Cache tokens: 0
Output tokens: 869947
Results written to /home/xisun/InfraBench/infra-bench/jobs/opencode-glm-5.2-fp8-onprem/result.json
Run log: /home/xisun/InfraBench/infra-bench/jobs/opencode-glm-5.2-fp8-onprem/run.log
```

Exception counts: `NonZeroAgentExitCodeError`=4, `AgentTimeoutError`=1.

All 20 trials have structured `agent/trajectory.json` files. Each trial also
has the raw OpenCode event log at `agent/opencode.txt`. The job metadata is
normalized as
`agent_info.name=opencode`, `agent_info.model_info.provider=onprem`, and
`agent_info.model_info.name=GLM-5.2-FP8`.

Scoreboard: **15/20 passed**.

Harbor upload: private job `4d6acd5f-a155-4c7b-bc77-c844a9819772`, uploaded
with `harbor upload /home/xisun/InfraBench/infra-bench/jobs/opencode-glm-5.2-fp8-onprem`
on 2026-07-19.

| Task | Reward | Trial | Trajectory/log | Exception |
|---|---:|---|---|---|
| `cute-layout-composition` | 0 | `cute-layout-composition__GVaxiXS` | `infra-bench/jobs/opencode-glm-5.2-fp8-onprem/cute-layout-composition__GVaxiXS/agent/trajectory.json` | `AgentTimeoutError` |
| `dwconv3d-occupancy` | 1 | `dwconv3d-occupancy__9yGEyKo` | `infra-bench/jobs/opencode-glm-5.2-fp8-onprem/dwconv3d-occupancy__9yGEyKo/agent/trajectory.json` |  |
| `engram-triton-kernel` | 1 | `engram-triton-kernel__bCeZHcC` | `infra-bench/jobs/opencode-glm-5.2-fp8-onprem/engram-triton-kernel__bCeZHcC/agent/trajectory.json` |  |
| `flydsl-cdna4-preshuffle-gemm` | 1 | `flydsl-cdna4-preshuffle-gemm__5AWpAdR` | `infra-bench/jobs/opencode-glm-5.2-fp8-onprem/flydsl-cdna4-preshuffle-gemm__5AWpAdR/agent/trajectory.json` |  |
| `gemm-fp8-ptpc-quant` | 1 | `gemm-fp8-ptpc-quant__aw7EMWd` | `infra-bench/jobs/opencode-glm-5.2-fp8-onprem/gemm-fp8-ptpc-quant__aw7EMWd/agent/trajectory.json` |  |
| `gemma4-gemm-tuning` | 1 | `gemma4-gemm-tuning__RDEzjLk` | `infra-bench/jobs/opencode-glm-5.2-fp8-onprem/gemma4-gemm-tuning__RDEzjLk/agent/trajectory.json` |  |
| `gemma4-sglang-serving-opt` | 0 | `gemma4-sglang-serving-opt__q8CDnSw` | `infra-bench/jobs/opencode-glm-5.2-fp8-onprem/gemma4-sglang-serving-opt__q8CDnSw/agent/trajectory.json` | `NonZeroAgentExitCodeError` |
| `gluon-a8w8-mfma-att` | 1 | `gluon-a8w8-mfma-att__JiJkdJc` | `infra-bench/jobs/opencode-glm-5.2-fp8-onprem/gluon-a8w8-mfma-att__JiJkdJc/agent/trajectory.json` |  |
| `hello-rocm` | 1 | `hello-rocm__8c4xSR4` | `infra-bench/jobs/opencode-glm-5.2-fp8-onprem/hello-rocm__8c4xSR4/agent/trajectory.json` |  |
| `hotspot-analysis-torch-profiler` | 1 | `hotspot-analysis-torch-profiler__r8MFsKV` | `infra-bench/jobs/opencode-glm-5.2-fp8-onprem/hotspot-analysis-torch-profiler__r8MFsKV/agent/trajectory.json` | `NonZeroAgentExitCodeError` |
| `llm-fp8-quantize` | 0 | `llm-fp8-quantize__iSKHqNV` | `infra-bench/jobs/opencode-glm-5.2-fp8-onprem/llm-fp8-quantize__iSKHqNV/agent/trajectory.json` | `NonZeroAgentExitCodeError` |
| `llvm-simple-constant-propagation` | 1 | `llvm-simple-constant-propagation__5KqLMti` | `infra-bench/jobs/opencode-glm-5.2-fp8-onprem/llvm-simple-constant-propagation__5KqLMti/agent/trajectory.json` |  |
| `mem-bandwidth-bench` | 1 | `mem-bandwidth-bench__SSgiCFm` | `infra-bench/jobs/opencode-glm-5.2-fp8-onprem/mem-bandwidth-bench__SSgiCFm/agent/trajectory.json` |  |
| `paged-attention-hd256` | 0 | `paged-attention-hd256__AXK2RYB` | `infra-bench/jobs/opencode-glm-5.2-fp8-onprem/paged-attention-hd256__AXK2RYB/agent/trajectory.json` |  |
| `pointnet2-hipify` | 1 | `pointnet2-hipify__9xe2M3G` | `infra-bench/jobs/opencode-glm-5.2-fp8-onprem/pointnet2-hipify__9xe2M3G/agent/trajectory.json` |  |
| `qr-rmsnorm-fusion` | 0 | `qr-rmsnorm-fusion__nutoW45` | `infra-bench/jobs/opencode-glm-5.2-fp8-onprem/qr-rmsnorm-fusion__nutoW45/agent/trajectory.json` |  |
| `sglang-mmmu-ipc-crash` | 1 | `sglang-mmmu-ipc-crash__edxJ36y` | `infra-bench/jobs/opencode-glm-5.2-fp8-onprem/sglang-mmmu-ipc-crash__edxJ36y/agent/trajectory.json` |  |
| `sglang-sync-stall` | 1 | `sglang-sync-stall__KZd2JHd` | `infra-bench/jobs/opencode-glm-5.2-fp8-onprem/sglang-sync-stall__KZd2JHd/agent/trajectory.json` |  |
| `triton-matmul-tuning` | 1 | `triton-matmul-tuning__mdoawbX` | `infra-bench/jobs/opencode-glm-5.2-fp8-onprem/triton-matmul-tuning__mdoawbX/agent/trajectory.json` |  |
| `vllm-aiter-debug` | 1 | `vllm-aiter-debug__b4AwTVJ` | `infra-bench/jobs/opencode-glm-5.2-fp8-onprem/vllm-aiter-debug__b4AwTVJ/agent/trajectory.json` | `NonZeroAgentExitCodeError` |

## Round 5 Results

Run date: 2026-07-19

Round 5 adds `MiniMax-M3` through OpenCode against an on-prem vLLM server at
`http://10.145.64.81:30000/v1`, using provider id `onprem`. The server launch
script is `minimax-m3-vllm/launch_vllm_minimax_m3_server.sh`.

Endpoint sanity: `GET /v1/models` returned `/models/MiniMax-M3`. The saved
`minimax-m3-vllm/run_sgl_ping.sh` log returned `pong`, and
`minimax-m3-vllm/run_sgl_gms8k.sh` completed 200 GSM8K examples with `98.50%`
score and `0.00%` error rate.

### Round 5 Smoke Tests

| Agent | Model | Job | Reward | Cost USD | Run log | Trajectory/log |
|---|---|---|---:|---:|---|---|
| opencode | `MiniMax-M3` | `smoke-opencode-minimax-m3-onprem` | 0/1 | - | `infra-bench/jobs/smoke-opencode-minimax-m3-onprem/run.log` | `infra-bench/jobs/smoke-opencode-minimax-m3-onprem/hello-rocm__9Knkfsn/agent/opencode.txt` (`trajectory.json` missing) |
| opencode | `/models/MiniMax-M3` | `smoke-opencode-minimax-m3-onprem-modelpath` | 1/1 | 0.014269 | `infra-bench/jobs/smoke-opencode-minimax-m3-onprem-modelpath/run.log` | `infra-bench/jobs/smoke-opencode-minimax-m3-onprem-modelpath/hello-rocm__g22kbaD/agent/trajectory.json` |

### `MiniMax-M3` via OpenCode On-Prem

First smoke command:

```bash
JOB_NAME=smoke-opencode-minimax-m3-onprem MODEL=MiniMax-M3 \
  AMD_OPENCODE_PROVIDER=onprem \
  AMD_CODEX_BASE_URL=http://10.145.64.81:30000/v1 \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' \
  ./run_open_code.sh -i hello-rocm
```

First smoke result summary:

```text
Trials: 1
Exceptions: 1
Reward 1.0: 0
Reward 0.0: 1
Exception: NonZeroAgentExitCodeError
Results written to /home/xisun/InfraBench/infra-bench/jobs/smoke-opencode-minimax-m3-onprem/result.json
Run log: /home/xisun/InfraBench/infra-bench/jobs/smoke-opencode-minimax-m3-onprem/run.log
```

Failure note: this was a model-id mismatch. vLLM advertised only
`/models/MiniMax-M3`, but OpenCode requested `MiniMax-M3`; the server returned
`404` with `The model MiniMax-M3 does not exist`.

Rerun smoke command with the exact vLLM model id:

```bash
JOB_NAME=smoke-opencode-minimax-m3-onprem-modelpath MODEL=/models/MiniMax-M3 \
  AMD_OPENCODE_PROVIDER=onprem \
  AMD_CODEX_BASE_URL=http://10.145.64.81:30000/v1 \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' \
  ./run_open_code.sh -i hello-rocm
```

Rerun result summary:

```text
Trials: 1
Exceptions: 0
Reward 1.0: 1
Reward 0.0: 0
Cost USD: 0.014269
Input tokens: 22973
Cache tokens: 0
Output tokens: 202
Results written to /home/xisun/InfraBench/infra-bench/jobs/smoke-opencode-minimax-m3-onprem-modelpath/result.json
Run log: /home/xisun/InfraBench/infra-bench/jobs/smoke-opencode-minimax-m3-onprem-modelpath/run.log
```

Full sweep command:

```bash
JOB_NAME=opencode-minimax-m3-onprem MODEL=/models/MiniMax-M3 \
  AMD_OPENCODE_PROVIDER=onprem \
  AMD_CODEX_BASE_URL=http://10.145.64.81:30000/v1 \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' \
  INFRA_PARALLEL=4 INFRABENCH_GPU_COUNT=8 ./run_open_code.sh
```

Full result summary:

```text
Trials: 20
Exceptions: 6
Reward 1.0: 12
Reward 0.0: 8
Mean reward: 0.600
Total runtime: 1h 30m 2s
Cost USD: 59.532313
Median agent execution: 7m 51s
Input tokens: 96050278
Cache tokens: 0
Output tokens: 792561
Results written to /home/xisun/InfraBench/infra-bench/jobs/opencode-minimax-m3-onprem/result.json
Run log: /home/xisun/InfraBench/infra-bench/jobs/opencode-minimax-m3-onprem/run.log
```

Exception counts: `NonZeroAgentExitCodeError`=3, `NetworkConnectionError`=1,
`AgentTimeoutError`=1, `ApiRateLimitError`=1.

All 20 trials have structured `agent/trajectory.json` files. Each trial also
has the raw OpenCode event log at `agent/opencode.txt`. The Hub display metadata
is normalized as `agent_info.name=opencode`,
`agent_info.model_info.provider=onprem`, and
`agent_info.model_info.name=MiniMax-M3`; the saved run config still records
`config.agent.model_name=onprem/models/MiniMax-M3` and the vLLM model key
`/models/MiniMax-M3` because those were required for the on-prem endpoint.

Scoreboard: **12/20 passed**.

Harbor upload: private job `a3dd9a27-c6a5-4ca4-82dd-2c09b36f0970`, uploaded
with `harbor upload /home/xisun/InfraBench/infra-bench/jobs/opencode-minimax-m3-onprem`
on 2026-07-19. The Hub job was deleted and re-uploaded on 2026-07-19 after
normalizing the display model metadata; Hub now shows `Models: MiniMax-M3` and
trial rows as `onprem/MiniMax-M3`.

| Task | Reward | Trial | Trajectory/log | Exception |
|---|---:|---|---|---|
| `cute-layout-composition` | 1 | `cute-layout-composition__uNdcuur` | `infra-bench/jobs/opencode-minimax-m3-onprem/cute-layout-composition__uNdcuur/agent/trajectory.json` |  |
| `dwconv3d-occupancy` | 1 | `dwconv3d-occupancy__LWndFwY` | `infra-bench/jobs/opencode-minimax-m3-onprem/dwconv3d-occupancy__LWndFwY/agent/trajectory.json` |  |
| `engram-triton-kernel` | 1 | `engram-triton-kernel__wdRDMf8` | `infra-bench/jobs/opencode-minimax-m3-onprem/engram-triton-kernel__wdRDMf8/agent/trajectory.json` |  |
| `flydsl-cdna4-preshuffle-gemm` | 0 | `flydsl-cdna4-preshuffle-gemm__GZMWy3w` | `infra-bench/jobs/opencode-minimax-m3-onprem/flydsl-cdna4-preshuffle-gemm__GZMWy3w/agent/trajectory.json` | `AgentTimeoutError` |
| `gemm-fp8-ptpc-quant` | 1 | `gemm-fp8-ptpc-quant__PC8rCgd` | `infra-bench/jobs/opencode-minimax-m3-onprem/gemm-fp8-ptpc-quant__PC8rCgd/agent/trajectory.json` |  |
| `gemma4-gemm-tuning` | 0 | `gemma4-gemm-tuning__hsx4xVJ` | `infra-bench/jobs/opencode-minimax-m3-onprem/gemma4-gemm-tuning__hsx4xVJ/agent/trajectory.json` |  |
| `gemma4-sglang-serving-opt` | 0 | `gemma4-sglang-serving-opt__Ue3DBst` | `infra-bench/jobs/opencode-minimax-m3-onprem/gemma4-sglang-serving-opt__Ue3DBst/agent/trajectory.json` | `NetworkConnectionError` |
| `gluon-a8w8-mfma-att` | 1 | `gluon-a8w8-mfma-att__xyERLbo` | `infra-bench/jobs/opencode-minimax-m3-onprem/gluon-a8w8-mfma-att__xyERLbo/agent/trajectory.json` |  |
| `hello-rocm` | 1 | `hello-rocm__KAjdKJ2` | `infra-bench/jobs/opencode-minimax-m3-onprem/hello-rocm__KAjdKJ2/agent/trajectory.json` |  |
| `hotspot-analysis-torch-profiler` | 0 | `hotspot-analysis-torch-profiler__A9VJrEQ` | `infra-bench/jobs/opencode-minimax-m3-onprem/hotspot-analysis-torch-profiler__A9VJrEQ/agent/trajectory.json` | `NonZeroAgentExitCodeError` |
| `llm-fp8-quantize` | 1 | `llm-fp8-quantize__DUgyQfY` | `infra-bench/jobs/opencode-minimax-m3-onprem/llm-fp8-quantize__DUgyQfY/agent/trajectory.json` | `NonZeroAgentExitCodeError` |
| `llvm-simple-constant-propagation` | 1 | `llvm-simple-constant-propagation__UrnBcWh` | `infra-bench/jobs/opencode-minimax-m3-onprem/llvm-simple-constant-propagation__UrnBcWh/agent/trajectory.json` |  |
| `mem-bandwidth-bench` | 1 | `mem-bandwidth-bench__56kN9UP` | `infra-bench/jobs/opencode-minimax-m3-onprem/mem-bandwidth-bench__56kN9UP/agent/trajectory.json` |  |
| `paged-attention-hd256` | 0 | `paged-attention-hd256__yUnVsTq` | `infra-bench/jobs/opencode-minimax-m3-onprem/paged-attention-hd256__yUnVsTq/agent/trajectory.json` |  |
| `pointnet2-hipify` | 1 | `pointnet2-hipify__EswnDZJ` | `infra-bench/jobs/opencode-minimax-m3-onprem/pointnet2-hipify__EswnDZJ/agent/trajectory.json` |  |
| `qr-rmsnorm-fusion` | 0 | `qr-rmsnorm-fusion__p9WWpqH` | `infra-bench/jobs/opencode-minimax-m3-onprem/qr-rmsnorm-fusion__p9WWpqH/agent/trajectory.json` |  |
| `sglang-mmmu-ipc-crash` | 1 | `sglang-mmmu-ipc-crash__L62bXT7` | `infra-bench/jobs/opencode-minimax-m3-onprem/sglang-mmmu-ipc-crash__L62bXT7/agent/trajectory.json` |  |
| `sglang-sync-stall` | 0 | `sglang-sync-stall__eHCnWJ2` | `infra-bench/jobs/opencode-minimax-m3-onprem/sglang-sync-stall__eHCnWJ2/agent/trajectory.json` | `ApiRateLimitError` |
| `triton-matmul-tuning` | 1 | `triton-matmul-tuning__22shJaC` | `infra-bench/jobs/opencode-minimax-m3-onprem/triton-matmul-tuning__22shJaC/agent/trajectory.json` |  |
| `vllm-aiter-debug` | 0 | `vllm-aiter-debug__MUCHkDo` | `infra-bench/jobs/opencode-minimax-m3-onprem/vllm-aiter-debug__MUCHkDo/agent/trajectory.json` | `NonZeroAgentExitCodeError` |

## Round 6 Results

Run date: 2026-07-19

Round 6 adds on-prem OpenCode sweeps for `Kimi-K2.7-Code`,
`Qwopus3.6-27B-Coder`, and `Qwopus3.6-35B-A3B-Coder`. The Kimi run uses the
on-prem vLLM server at `http://10.145.64.81:30000/v1`; vLLM advertises only
`/models/Kimi-K2.7-Code`, so OpenCode must request that exact served model id.

### Round 6 Smoke Tests

| Agent | Model | Job | Reward | Cost USD | Run log | Trajectory/log |
|---|---|---|---:|---:|---|---|
| opencode | `/models/Kimi-K2.7-Code` | `smoke-opencode-kimi-k2.7-code-onprem-modelpath` | 1/1 | 0.013587 | `infra-bench/jobs/smoke-opencode-kimi-k2.7-code-onprem-modelpath/run.log` | `infra-bench/jobs/smoke-opencode-kimi-k2.7-code-onprem-modelpath/hello-rocm__fQek2du/agent/trajectory.json` |
| opencode | `/models/Qwopus3.6-27B-Coder` | `smoke-opencode-qwopus3.6-27b-coder-onprem-modelpath` | 0/1 | - | `infra-bench/jobs/smoke-opencode-qwopus3.6-27b-coder-onprem-modelpath/run.log` | `infra-bench/jobs/smoke-opencode-qwopus3.6-27b-coder-onprem-modelpath/hello-rocm__xALpSMD/agent/opencode.txt` |
| opencode | `/models/Qwopus3.6-27B-Coder` | `smoke-opencode-qwopus3.6-27b-coder-onprem-modelpath-rerun` | 0/1 | - | `infra-bench/jobs/smoke-opencode-qwopus3.6-27b-coder-onprem-modelpath-rerun/run.log` | `infra-bench/jobs/smoke-opencode-qwopus3.6-27b-coder-onprem-modelpath-rerun/hello-rocm__HqrRVxX/agent/opencode.txt` |
| opencode | `/models/Qwopus3.6-27B-Coder` | `smoke-opencode-qwopus3.6-27b-coder-onprem-modelpath-rerun2` | 0/1 | - | `infra-bench/jobs/smoke-opencode-qwopus3.6-27b-coder-onprem-modelpath-rerun2/run.log` | `infra-bench/jobs/smoke-opencode-qwopus3.6-27b-coder-onprem-modelpath-rerun2/hello-rocm__dnpwEuT/agent/opencode.txt` |
| opencode | `/models/Qwopus3.6-35B-A3B-Coder` | `smoke-opencode-qwopus3.6-35b-a3b-coder-onprem-modelpath` | 0/1 | - | `infra-bench/jobs/smoke-opencode-qwopus3.6-35b-a3b-coder-onprem-modelpath/run.log` | `infra-bench/jobs/smoke-opencode-qwopus3.6-35b-a3b-coder-onprem-modelpath/hello-rocm__MnsJTgy/agent/opencode.txt` |
| opencode | `/models/Qwopus3.6-27B-Coder` | `smoke-opencode-qwopus3.6-27b-coder-onprem-hostip` | 1/1 | 0.002430 | `infra-bench/jobs/smoke-opencode-qwopus3.6-27b-coder-onprem-hostip/run.log` | `infra-bench/jobs/smoke-opencode-qwopus3.6-27b-coder-onprem-hostip/hello-rocm__Dhsbzms/agent/trajectory.json` |
| opencode | `/models/Qwopus3.6-35B-A3B-Coder` | `smoke-opencode-qwopus3.6-35b-a3b-coder-onprem-hostip` | 1/1 | 0.006440 | `infra-bench/jobs/smoke-opencode-qwopus3.6-35b-a3b-coder-onprem-hostip/run.log` | `infra-bench/jobs/smoke-opencode-qwopus3.6-35b-a3b-coder-onprem-hostip/hello-rocm__iTMzomG/agent/trajectory.json` |

### `Kimi-K2.7-Code` via OpenCode On-Prem

Smoke command:

```bash
JOB_NAME=smoke-opencode-kimi-k2.7-code-onprem-modelpath \
  MODEL=/models/Kimi-K2.7-Code \
  AMD_OPENCODE_PROVIDER=onprem \
  AMD_CODEX_BASE_URL=http://10.145.64.81:30000/v1 \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' \
  ./run_open_code.sh -i hello-rocm
```

Smoke result summary:

```text
Trials: 1
Exceptions: 0
Reward 1.0: 1
Reward 0.0: 0
Cost USD: 0.013587
Input tokens: 13279
Cache tokens: 0
Output tokens: 243
Results written to /home/xisun/InfraBench/infra-bench/jobs/smoke-opencode-kimi-k2.7-code-onprem-modelpath/result.json
Run log: /home/xisun/InfraBench/infra-bench/jobs/smoke-opencode-kimi-k2.7-code-onprem-modelpath/run.log
```

Full sweep command:

```bash
JOB_NAME=opencode-kimi-k2.7-code-onprem MODEL=/models/Kimi-K2.7-Code \
  AMD_OPENCODE_PROVIDER=onprem \
  AMD_CODEX_BASE_URL=http://10.145.64.81:30000/v1 \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' \
  INFRA_PARALLEL=4 INFRABENCH_GPU_COUNT=8 ./run_open_code.sh
```

Full result summary:

```text
Trials: 20
Exceptions: 6
Reward 1.0: 18
Reward 0.0: 2
Mean reward: 0.900
Total runtime: 3h 30m 39s
Cost USD: 96.618066
Median agent execution: 18m 27s
Input tokens: 97838806
Cache tokens: 0
Output tokens: 917800
Results written to /home/xisun/InfraBench/infra-bench/jobs/opencode-kimi-k2.7-code-onprem/result.json
Run log: /home/xisun/InfraBench/infra-bench/jobs/opencode-kimi-k2.7-code-onprem/run.log
```

Exception counts: `AgentTimeoutError`=3, `NonZeroAgentExitCodeError`=2,
`ApiRateLimitError`=1.

All 20 trials have structured `agent/trajectory.json` files and raw OpenCode
event logs at `agent/opencode.txt`. The job artifacts were checked after the
run and the gateway header was scrubbed from the saved JSON metadata. Before
upload, display metadata was normalized from `/models/Kimi-K2.7-Code` to
`Kimi-K2.7-Code`:
`stats.evals` now uses `opencode__Kimi-K2.7-Code__infra-bench`, trial
`agent_info.model_info.name=Kimi-K2.7-Code`, and the saved run config records
`config.agent.model_name=onprem/models/Kimi-K2.7-Code` with provider catalog key
`Kimi-K2.7-Code`.

Scoreboard: **18/20 passed**.

Harbor upload: private job `72208869-fb6a-40ae-88c2-fd70fc944c71`, uploaded
with `harbor upload /home/xisun/InfraBench/infra-bench/jobs/opencode-kimi-k2.7-code-onprem`
on 2026-07-19.

| Task | Reward | Trial | Trajectory/log | Exception |
|---|---:|---|---|---|
| `cute-layout-composition` | 1 | `cute-layout-composition__EXwBo6p` | `infra-bench/jobs/opencode-kimi-k2.7-code-onprem/cute-layout-composition__EXwBo6p/agent/trajectory.json` | `AgentTimeoutError` |
| `dwconv3d-occupancy` | 1 | `dwconv3d-occupancy__9ipvZR6` | `infra-bench/jobs/opencode-kimi-k2.7-code-onprem/dwconv3d-occupancy__9ipvZR6/agent/trajectory.json` |  |
| `engram-triton-kernel` | 1 | `engram-triton-kernel__EojdHbs` | `infra-bench/jobs/opencode-kimi-k2.7-code-onprem/engram-triton-kernel__EojdHbs/agent/trajectory.json` | `AgentTimeoutError` |
| `flydsl-cdna4-preshuffle-gemm` | 1 | `flydsl-cdna4-preshuffle-gemm__GDk4f4y` | `infra-bench/jobs/opencode-kimi-k2.7-code-onprem/flydsl-cdna4-preshuffle-gemm__GDk4f4y/agent/trajectory.json` |  |
| `gemm-fp8-ptpc-quant` | 1 | `gemm-fp8-ptpc-quant__jan3wXZ` | `infra-bench/jobs/opencode-kimi-k2.7-code-onprem/gemm-fp8-ptpc-quant__jan3wXZ/agent/trajectory.json` |  |
| `gemma4-gemm-tuning` | 0 | `gemma4-gemm-tuning__AGrUTTg` | `infra-bench/jobs/opencode-kimi-k2.7-code-onprem/gemma4-gemm-tuning__AGrUTTg/agent/trajectory.json` |  |
| `gemma4-sglang-serving-opt` | 1 | `gemma4-sglang-serving-opt__mZ2xq2T` | `infra-bench/jobs/opencode-kimi-k2.7-code-onprem/gemma4-sglang-serving-opt__mZ2xq2T/agent/trajectory.json` | `AgentTimeoutError` |
| `gluon-a8w8-mfma-att` | 1 | `gluon-a8w8-mfma-att__d94ZXe4` | `infra-bench/jobs/opencode-kimi-k2.7-code-onprem/gluon-a8w8-mfma-att__d94ZXe4/agent/trajectory.json` |  |
| `hello-rocm` | 1 | `hello-rocm__Gr7WFRe` | `infra-bench/jobs/opencode-kimi-k2.7-code-onprem/hello-rocm__Gr7WFRe/agent/trajectory.json` |  |
| `hotspot-analysis-torch-profiler` | 1 | `hotspot-analysis-torch-profiler__hypAE8W` | `infra-bench/jobs/opencode-kimi-k2.7-code-onprem/hotspot-analysis-torch-profiler__hypAE8W/agent/trajectory.json` | `ApiRateLimitError` |
| `llm-fp8-quantize` | 1 | `llm-fp8-quantize__hiLmLMv` | `infra-bench/jobs/opencode-kimi-k2.7-code-onprem/llm-fp8-quantize__hiLmLMv/agent/trajectory.json` | `NonZeroAgentExitCodeError` |
| `llvm-simple-constant-propagation` | 1 | `llvm-simple-constant-propagation__HgpjFMd` | `infra-bench/jobs/opencode-kimi-k2.7-code-onprem/llvm-simple-constant-propagation__HgpjFMd/agent/trajectory.json` |  |
| `mem-bandwidth-bench` | 1 | `mem-bandwidth-bench__vzaagGu` | `infra-bench/jobs/opencode-kimi-k2.7-code-onprem/mem-bandwidth-bench__vzaagGu/agent/trajectory.json` |  |
| `paged-attention-hd256` | 0 | `paged-attention-hd256__Mxu39Mw` | `infra-bench/jobs/opencode-kimi-k2.7-code-onprem/paged-attention-hd256__Mxu39Mw/agent/trajectory.json` |  |
| `pointnet2-hipify` | 1 | `pointnet2-hipify__PoUp7kp` | `infra-bench/jobs/opencode-kimi-k2.7-code-onprem/pointnet2-hipify__PoUp7kp/agent/trajectory.json` |  |
| `qr-rmsnorm-fusion` | 1 | `qr-rmsnorm-fusion__MQjfgMx` | `infra-bench/jobs/opencode-kimi-k2.7-code-onprem/qr-rmsnorm-fusion__MQjfgMx/agent/trajectory.json` |  |
| `sglang-mmmu-ipc-crash` | 1 | `sglang-mmmu-ipc-crash__srWqRBG` | `infra-bench/jobs/opencode-kimi-k2.7-code-onprem/sglang-mmmu-ipc-crash__srWqRBG/agent/trajectory.json` |  |
| `sglang-sync-stall` | 1 | `sglang-sync-stall__JoCGCbQ` | `infra-bench/jobs/opencode-kimi-k2.7-code-onprem/sglang-sync-stall__JoCGCbQ/agent/trajectory.json` |  |
| `triton-matmul-tuning` | 1 | `triton-matmul-tuning__Ys82qKL` | `infra-bench/jobs/opencode-kimi-k2.7-code-onprem/triton-matmul-tuning__Ys82qKL/agent/trajectory.json` |  |
| `vllm-aiter-debug` | 1 | `vllm-aiter-debug__ScdPoAv` | `infra-bench/jobs/opencode-kimi-k2.7-code-onprem/vllm-aiter-debug__ScdPoAv/agent/trajectory.json` | `NonZeroAgentExitCodeError` |

### Qwopus3.6 OpenCode Smoke Triage

The Qwopus servers are reachable from the host and advertise the expected model
ids: `/models/Qwopus3.6-27B-Coder` on port 9527 and
`/models/Qwopus3.6-35B-A3B-Coder` on port 9528. OpenCode runs inside
InfraBench task containers, so `127.0.0.1` points at the task container rather
than the host/container serving Qwopus. The working endpoint for task containers
is the host-routable IP `10.145.64.87`.

Direct local Chat Completions probes showed parser-specific tool-call formats:
`Qwopus3.6-27B-Coder` emits Qwen JSON `<tool_call>...</tool_call>` blocks, so
the local launch script was adjusted to `--tool-call-parser qwen25`;
`Qwopus3.6-35B-A3B-Coder` emits `<function=...><parameter=...>` blocks and
uses `--tool-call-parser qwen3_coder`. With those parser settings, direct local
tool-call probes returned structured OpenAI `tool_calls` for both endpoints.

The first OpenCode `hello-rocm` smokes used `127.0.0.1` and timed out before
producing any OpenCode event output. Each failed smoke has an empty
`agent/opencode.txt`, an `AgentTimeoutError`, no token/cost accounting, and
verifier reward 0 because the agent never wrote `/app/gpu_report.json`. After
switching `AMD_CODEX_BASE_URL` to `http://10.145.64.87:<port>/v1`, `hello-rocm`
passed for both Qwopus models, so full sweeps can proceed with
`INFRABENCH_GPU_COUNT=6` to avoid GPUs 6/7 used by the Qwopus servers.

Failed 27B smoke with the original `qwen3_coder` parser:

```bash
JOB_NAME=smoke-opencode-qwopus3.6-27b-coder-onprem-modelpath \
  MODEL=/models/Qwopus3.6-27B-Coder \
  AMD_OPENCODE_PROVIDER=onprem \
  AMD_CODEX_BASE_URL=http://127.0.0.1:9527/v1 \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' \
  INFRABENCH_GPU_COUNT=6 \
  ./run_open_code.sh -i hello-rocm
```

Result summary:

```text
Trials: 1
Exceptions: 1
Reward 1.0: 0
Reward 0.0: 1
Exception: AgentTimeoutError
Total runtime: 10m 54s
Results written to /home/xisun/InfraBench/infra-bench/jobs/smoke-opencode-qwopus3.6-27b-coder-onprem-modelpath/result.json
```

Failed 27B smoke after switching the 27B server to `qwen25` and doubling the
timeout:

```bash
JOB_NAME=smoke-opencode-qwopus3.6-27b-coder-onprem-modelpath-rerun2 \
  MODEL=/models/Qwopus3.6-27B-Coder \
  AMD_OPENCODE_PROVIDER=onprem \
  AMD_CODEX_BASE_URL=http://127.0.0.1:9527/v1 \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' \
  INFRABENCH_GPU_COUNT=6 \
  ./run_open_code.sh -i hello-rocm --timeout-multiplier 2
```

Result summary:

```text
Trials: 1
Exceptions: 1
Reward 1.0: 0
Reward 0.0: 1
Exception: AgentTimeoutError
Total runtime: 25m 6s
Results written to /home/xisun/InfraBench/infra-bench/jobs/smoke-opencode-qwopus3.6-27b-coder-onprem-modelpath-rerun2/result.json
```

Failed 35B smoke with `qwen3_coder` and doubled timeout:

```bash
JOB_NAME=smoke-opencode-qwopus3.6-35b-a3b-coder-onprem-modelpath \
  MODEL=/models/Qwopus3.6-35B-A3B-Coder \
  AMD_OPENCODE_PROVIDER=onprem \
  AMD_CODEX_BASE_URL=http://127.0.0.1:9528/v1 \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' \
  INFRABENCH_GPU_COUNT=6 \
  ./run_open_code.sh -i hello-rocm --timeout-multiplier 2
```

Result summary:

```text
Trials: 1
Exceptions: 1
Reward 1.0: 0
Reward 0.0: 1
Exception: AgentTimeoutError
Total runtime: 20m 36s
Results written to /home/xisun/InfraBench/infra-bench/jobs/smoke-opencode-qwopus3.6-35b-a3b-coder-onprem-modelpath/result.json
```

Passed 27B smoke using the host-routable endpoint:

```bash
JOB_NAME=smoke-opencode-qwopus3.6-27b-coder-onprem-hostip \
  MODEL=/models/Qwopus3.6-27B-Coder \
  AMD_OPENCODE_PROVIDER=onprem \
  AMD_CODEX_BASE_URL=http://10.145.64.87:9527/v1 \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' \
  INFRABENCH_GPU_COUNT=6 \
  ./run_open_code.sh -i hello-rocm
```

Result summary:

```text
Trials: 1
Exceptions: 0
Reward 1.0: 1
Reward 0.0: 0
Cost USD: 0.002430
Input tokens: 15506
Cache tokens: 0
Output tokens: 208
Total runtime: 51s
Results written to /home/xisun/InfraBench/infra-bench/jobs/smoke-opencode-qwopus3.6-27b-coder-onprem-hostip/result.json
Run log: /home/xisun/InfraBench/infra-bench/jobs/smoke-opencode-qwopus3.6-27b-coder-onprem-hostip/run.log
```

Passed 35B smoke using the host-routable endpoint:

```bash
JOB_NAME=smoke-opencode-qwopus3.6-35b-a3b-coder-onprem-hostip \
  MODEL=/models/Qwopus3.6-35B-A3B-Coder \
  AMD_OPENCODE_PROVIDER=onprem \
  AMD_CODEX_BASE_URL=http://10.145.64.87:9528/v1 \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' \
  INFRABENCH_GPU_COUNT=6 \
  ./run_open_code.sh -i hello-rocm
```

Result summary:

```text
Trials: 1
Exceptions: 0
Reward 1.0: 1
Reward 0.0: 0
Cost USD: 0.006440
Input tokens: 23906
Cache tokens: 0
Output tokens: 309
Total runtime: 41s
Results written to /home/xisun/InfraBench/infra-bench/jobs/smoke-opencode-qwopus3.6-35b-a3b-coder-onprem-hostip/result.json
Run log: /home/xisun/InfraBench/infra-bench/jobs/smoke-opencode-qwopus3.6-35b-a3b-coder-onprem-hostip/run.log
```

### `Qwopus3.6-35B-A3B-Coder` via OpenCode On-Prem

Full sweep command:

```bash
JOB_NAME=opencode-qwopus3.6-35b-a3b-coder-onprem \
  MODEL=/models/Qwopus3.6-35B-A3B-Coder \
  AMD_OPENCODE_PROVIDER=onprem \
  AMD_CODEX_BASE_URL=http://10.145.64.87:9528/v1 \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' \
  INFRA_PARALLEL=4 \
  INFRABENCH_GPU_COUNT=6 \
  ./run_open_code.sh
```

Full result summary:

```text
Trials: 20
Exceptions: 9
Reward 1.0: 4
Reward 0.0: 16
Mean reward: 0.200
Total runtime: 2h 35m 47s
Cost USD: 5.500557
Median agent execution: 5m 20s
Input tokens: 19727018
Cache tokens: 0
Output tokens: 379202
Results written to /home/xisun/InfraBench/infra-bench/jobs/opencode-qwopus3.6-35b-a3b-coder-onprem/result.json
Run log: /home/xisun/InfraBench/infra-bench/jobs/opencode-qwopus3.6-35b-a3b-coder-onprem/run.log
```

Exception counts: `AgentTimeoutError`=6, `NonZeroAgentExitCodeError`=3.

All 20 trials have structured `agent/trajectory.json` files and raw OpenCode
event logs at `agent/opencode.txt`. The `engram-triton-kernel`,
`llm-fp8-quantize`, and `mem-bandwidth-bench` trials use reconstructed partial
trajectories because the OpenCode JSON stream ended before a complete
`step_finish` event. The saved JSON artifacts were checked after the run, and
gateway header values are redacted.

Display metadata was normalized before upload:
`stats.evals=opencode__Qwopus3.6-35B-A3B-Coder__infra-bench`, trial
`agent_info.model_info.name=Qwopus3.6-35B-A3B-Coder`, saved run config
`config.agent.model_name=onprem/models/Qwopus3.6-35B-A3B-Coder`, and provider
catalog key `Qwopus3.6-35B-A3B-Coder`.

Scoreboard: **4/20 passed**.

Harbor upload: private job `f38efb7a-e3a9-4c8a-a324-b27864415c63`, uploaded
with `harbor upload /home/xisun/InfraBench/infra-bench/jobs/opencode-qwopus3.6-35b-a3b-coder-onprem`
on 2026-07-20. Hub URL:
`https://hub.harborframework.com/jobs/f38efb7a-e3a9-4c8a-a324-b27864415c63`.

| Task | Reward | Trial | Trajectory/log | Exception |
|---|---:|---|---|---|
| `cute-layout-composition` | 0 | `cute-layout-composition__eokrozA` | `infra-bench/jobs/opencode-qwopus3.6-35b-a3b-coder-onprem/cute-layout-composition__eokrozA/agent/trajectory.json` |  |
| `dwconv3d-occupancy` | 0 | `dwconv3d-occupancy__CLHeup3` | `infra-bench/jobs/opencode-qwopus3.6-35b-a3b-coder-onprem/dwconv3d-occupancy__CLHeup3/agent/trajectory.json` |  |
| `engram-triton-kernel` | 0 | `engram-triton-kernel__TUQV8RQ` | `infra-bench/jobs/opencode-qwopus3.6-35b-a3b-coder-onprem/engram-triton-kernel__TUQV8RQ/agent/trajectory.json` | `NonZeroAgentExitCodeError` |
| `flydsl-cdna4-preshuffle-gemm` | 0 | `flydsl-cdna4-preshuffle-gemm__LeQmP8r` | `infra-bench/jobs/opencode-qwopus3.6-35b-a3b-coder-onprem/flydsl-cdna4-preshuffle-gemm__LeQmP8r/agent/trajectory.json` | `AgentTimeoutError` |
| `gemm-fp8-ptpc-quant` | 0 | `gemm-fp8-ptpc-quant__ZD2VfqS` | `infra-bench/jobs/opencode-qwopus3.6-35b-a3b-coder-onprem/gemm-fp8-ptpc-quant__ZD2VfqS/agent/trajectory.json` |  |
| `gemma4-gemm-tuning` | 0 | `gemma4-gemm-tuning__xv77Cyg` | `infra-bench/jobs/opencode-qwopus3.6-35b-a3b-coder-onprem/gemma4-gemm-tuning__xv77Cyg/agent/trajectory.json` |  |
| `gemma4-sglang-serving-opt` | 0 | `gemma4-sglang-serving-opt__ejApVCR` | `infra-bench/jobs/opencode-qwopus3.6-35b-a3b-coder-onprem/gemma4-sglang-serving-opt__ejApVCR/agent/trajectory.json` | `AgentTimeoutError` |
| `gluon-a8w8-mfma-att` | 0 | `gluon-a8w8-mfma-att__taTcA5C` | `infra-bench/jobs/opencode-qwopus3.6-35b-a3b-coder-onprem/gluon-a8w8-mfma-att__taTcA5C/agent/trajectory.json` | `AgentTimeoutError` |
| `hello-rocm` | 1 | `hello-rocm__TgTPkYe` | `infra-bench/jobs/opencode-qwopus3.6-35b-a3b-coder-onprem/hello-rocm__TgTPkYe/agent/trajectory.json` |  |
| `hotspot-analysis-torch-profiler` | 0 | `hotspot-analysis-torch-profiler__q4SB2qc` | `infra-bench/jobs/opencode-qwopus3.6-35b-a3b-coder-onprem/hotspot-analysis-torch-profiler__q4SB2qc/agent/trajectory.json` | `NonZeroAgentExitCodeError` |
| `llm-fp8-quantize` | 0 | `llm-fp8-quantize__YgMxs3N` | `infra-bench/jobs/opencode-qwopus3.6-35b-a3b-coder-onprem/llm-fp8-quantize__YgMxs3N/agent/trajectory.json` | `AgentTimeoutError` |
| `llvm-simple-constant-propagation` | 1 | `llvm-simple-constant-propagation__T9xejC8` | `infra-bench/jobs/opencode-qwopus3.6-35b-a3b-coder-onprem/llvm-simple-constant-propagation__T9xejC8/agent/trajectory.json` |  |
| `mem-bandwidth-bench` | 0 | `mem-bandwidth-bench__V75J9DJ` | `infra-bench/jobs/opencode-qwopus3.6-35b-a3b-coder-onprem/mem-bandwidth-bench__V75J9DJ/agent/trajectory.json` | `AgentTimeoutError` |
| `paged-attention-hd256` | 0 | `paged-attention-hd256__gF26u82` | `infra-bench/jobs/opencode-qwopus3.6-35b-a3b-coder-onprem/paged-attention-hd256__gF26u82/agent/trajectory.json` |  |
| `pointnet2-hipify` | 0 | `pointnet2-hipify__dGmV2v2` | `infra-bench/jobs/opencode-qwopus3.6-35b-a3b-coder-onprem/pointnet2-hipify__dGmV2v2/agent/trajectory.json` | `AgentTimeoutError` |
| `qr-rmsnorm-fusion` | 0 | `qr-rmsnorm-fusion__pvFf4Ws` | `infra-bench/jobs/opencode-qwopus3.6-35b-a3b-coder-onprem/qr-rmsnorm-fusion__pvFf4Ws/agent/trajectory.json` |  |
| `sglang-mmmu-ipc-crash` | 1 | `sglang-mmmu-ipc-crash__qtxL6Lw` | `infra-bench/jobs/opencode-qwopus3.6-35b-a3b-coder-onprem/sglang-mmmu-ipc-crash__qtxL6Lw/agent/trajectory.json` |  |
| `sglang-sync-stall` | 0 | `sglang-sync-stall__g56jWYZ` | `infra-bench/jobs/opencode-qwopus3.6-35b-a3b-coder-onprem/sglang-sync-stall__g56jWYZ/agent/trajectory.json` |  |
| `triton-matmul-tuning` | 0 | `triton-matmul-tuning__99YDNDD` | `infra-bench/jobs/opencode-qwopus3.6-35b-a3b-coder-onprem/triton-matmul-tuning__99YDNDD/agent/trajectory.json` |  |
| `vllm-aiter-debug` | 1 | `vllm-aiter-debug__pEsHYJ8` | `infra-bench/jobs/opencode-qwopus3.6-35b-a3b-coder-onprem/vllm-aiter-debug__pEsHYJ8/agent/trajectory.json` | `NonZeroAgentExitCodeError` |

## Round 7 Results

Run date: 2026-07-20

Round 7 adds an on-prem OpenCode sweep for `Qwen3.5-397B-A17B-FP8`. The model is
served by SGLang from
`/home/xisun/InfraBench/qwen3.5-397b-fp8/launch_sgl_qwen3.5_397b_server.sh` on
another MI350 machine at `http://10.145.64.81:30000/v1`. SGLang advertises the
model id `/models/Qwen3.5-397B-A17B-FP8`, so OpenCode must request that exact
served model id.

LiteLLM has `Qwen3.5-397B-A17B-FP8` pricing at `$0.60/M` input and `$3.60/M`
output. The exact TensorMesh FP8 key lists cache-read as zero, but this run uses
`$0.60/M` cache-read for conservative comparison. The completed full sweep
reported zero cache tokens, so this choice did not affect the final cost.

An interrupted pre-change full-sweep attempt that still had cache-read set to
`$0.00/M` was stopped and moved to
`infra-bench/jobs/opencode-qwen3.5-397b-a17b-fp8-onprem_cache0_stopped_20260720_070655`.
The final job below is the clean rerun with cache-read set to `$0.60/M`.

### Round 7 Smoke Test

Smoke command:

```bash
JOB_NAME=smoke-opencode-qwen3.5-397b-a17b-fp8-onprem \
  MODEL=/models/Qwen3.5-397B-A17B-FP8 \
  AMD_OPENCODE_PROVIDER=onprem \
  AMD_CODEX_BASE_URL=http://10.145.64.81:30000/v1 \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' \
  INFRABENCH_GPU_COUNT=6 \
  ./run_open_code.sh -i hello-rocm
```

Smoke result summary:

```text
Trials: 1
Exceptions: 0
Reward 1.0: 1
Reward 0.0: 0
Cost USD: 0.011036
Input tokens: 15880
Cache tokens: 0
Output tokens: 419
Total runtime: 46s
Results written to /home/xisun/InfraBench/infra-bench/jobs/smoke-opencode-qwen3.5-397b-a17b-fp8-onprem/result.json
Run log: /home/xisun/InfraBench/infra-bench/jobs/smoke-opencode-qwen3.5-397b-a17b-fp8-onprem/run.log
```

### `Qwen3.5-397B-A17B-FP8` via OpenCode On-Prem

Full sweep command:

```bash
JOB_NAME=opencode-qwen3.5-397b-a17b-fp8-onprem \
  MODEL=/models/Qwen3.5-397B-A17B-FP8 \
  AMD_OPENCODE_PROVIDER=onprem \
  AMD_CODEX_BASE_URL=http://10.145.64.81:30000/v1 \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' \
  INFRA_PARALLEL=4 \
  INFRABENCH_GPU_COUNT=6 \
  ./run_open_code.sh
```

Full result summary:

```text
Trials: 20
Exceptions: 4
Reward 1.0: 9
Reward 0.0: 11
Mean reward: 0.450
Total runtime: 50m 57s
Cost USD: 23.439468
Median agent execution: 4m 40s
Input tokens: 36833348
Cache tokens: 0
Output tokens: 372072
Results written to /home/xisun/InfraBench/infra-bench/jobs/opencode-qwen3.5-397b-a17b-fp8-onprem/result.json
Run log: /home/xisun/InfraBench/infra-bench/jobs/opencode-qwen3.5-397b-a17b-fp8-onprem/run.log
```

Exception counts: `NonZeroAgentExitCodeError`=2, `ApiRateLimitError`=1,
`NetworkConnectionError`=1.

All 20 trials have structured `agent/trajectory.json` files and raw OpenCode
event logs at `agent/opencode.txt`. The saved JSON artifacts were checked after
the run, and gateway header values are redacted. Display metadata was normalized
before documenting the result:
`stats.evals=opencode__Qwen3.5-397B-A17B-FP8__infra-bench`, trial
`agent_info.model_info.name=Qwen3.5-397B-A17B-FP8`, saved run config
`config.agent.model_name=onprem/models/Qwen3.5-397B-A17B-FP8`, and provider
catalog key `Qwen3.5-397B-A17B-FP8`.

Scoreboard: **9/20 passed**.

Harbor upload: private job `3ec1f3ce-0a1e-4974-bbc9-e54535b648cb`, uploaded
with `harbor upload /home/xisun/InfraBench/infra-bench/jobs/opencode-qwen3.5-397b-a17b-fp8-onprem`
on 2026-07-20. Hub URL:
`https://hub.harborframework.com/jobs/3ec1f3ce-0a1e-4974-bbc9-e54535b648cb`.

| Task | Reward | Trial | Trajectory/log | Exception |
|---|---:|---|---|---|
| `cute-layout-composition` | 0 | `cute-layout-composition__s3wTAsF` | `infra-bench/jobs/opencode-qwen3.5-397b-a17b-fp8-onprem/cute-layout-composition__s3wTAsF/agent/trajectory.json` |  |
| `dwconv3d-occupancy` | 1 | `dwconv3d-occupancy__FxG6JYC` | `infra-bench/jobs/opencode-qwen3.5-397b-a17b-fp8-onprem/dwconv3d-occupancy__FxG6JYC/agent/trajectory.json` |  |
| `engram-triton-kernel` | 1 | `engram-triton-kernel__C9Nd5Nu` | `infra-bench/jobs/opencode-qwen3.5-397b-a17b-fp8-onprem/engram-triton-kernel__C9Nd5Nu/agent/trajectory.json` |  |
| `flydsl-cdna4-preshuffle-gemm` | 1 | `flydsl-cdna4-preshuffle-gemm__NWr8B5U` | `infra-bench/jobs/opencode-qwen3.5-397b-a17b-fp8-onprem/flydsl-cdna4-preshuffle-gemm__NWr8B5U/agent/trajectory.json` |  |
| `gemm-fp8-ptpc-quant` | 0 | `gemm-fp8-ptpc-quant__3uavqBT` | `infra-bench/jobs/opencode-qwen3.5-397b-a17b-fp8-onprem/gemm-fp8-ptpc-quant__3uavqBT/agent/trajectory.json` |  |
| `gemma4-gemm-tuning` | 0 | `gemma4-gemm-tuning__cMEydqh` | `infra-bench/jobs/opencode-qwen3.5-397b-a17b-fp8-onprem/gemma4-gemm-tuning__cMEydqh/agent/trajectory.json` |  |
| `gemma4-sglang-serving-opt` | 0 | `gemma4-sglang-serving-opt__4kYRKja` | `infra-bench/jobs/opencode-qwen3.5-397b-a17b-fp8-onprem/gemma4-sglang-serving-opt__4kYRKja/agent/trajectory.json` |  |
| `gluon-a8w8-mfma-att` | 1 | `gluon-a8w8-mfma-att__qWyA4Mw` | `infra-bench/jobs/opencode-qwen3.5-397b-a17b-fp8-onprem/gluon-a8w8-mfma-att__qWyA4Mw/agent/trajectory.json` |  |
| `hello-rocm` | 1 | `hello-rocm__CyER34V` | `infra-bench/jobs/opencode-qwen3.5-397b-a17b-fp8-onprem/hello-rocm__CyER34V/agent/trajectory.json` |  |
| `hotspot-analysis-torch-profiler` | 0 | `hotspot-analysis-torch-profiler__3UuBGA7` | `infra-bench/jobs/opencode-qwen3.5-397b-a17b-fp8-onprem/hotspot-analysis-torch-profiler__3UuBGA7/agent/trajectory.json` | `NonZeroAgentExitCodeError` |
| `llm-fp8-quantize` | 0 | `llm-fp8-quantize__BBeVosa` | `infra-bench/jobs/opencode-qwen3.5-397b-a17b-fp8-onprem/llm-fp8-quantize__BBeVosa/agent/trajectory.json` | `NonZeroAgentExitCodeError` |
| `llvm-simple-constant-propagation` | 1 | `llvm-simple-constant-propagation__gSjwC5j` | `infra-bench/jobs/opencode-qwen3.5-397b-a17b-fp8-onprem/llvm-simple-constant-propagation__gSjwC5j/agent/trajectory.json` |  |
| `mem-bandwidth-bench` | 0 | `mem-bandwidth-bench__MFKuHGR` | `infra-bench/jobs/opencode-qwen3.5-397b-a17b-fp8-onprem/mem-bandwidth-bench__MFKuHGR/agent/trajectory.json` |  |
| `paged-attention-hd256` | 0 | `paged-attention-hd256__qXEy22o` | `infra-bench/jobs/opencode-qwen3.5-397b-a17b-fp8-onprem/paged-attention-hd256__qXEy22o/agent/trajectory.json` |  |
| `pointnet2-hipify` | 1 | `pointnet2-hipify__C6mRh7m` | `infra-bench/jobs/opencode-qwen3.5-397b-a17b-fp8-onprem/pointnet2-hipify__C6mRh7m/agent/trajectory.json` |  |
| `qr-rmsnorm-fusion` | 0 | `qr-rmsnorm-fusion__dTJLwbR` | `infra-bench/jobs/opencode-qwen3.5-397b-a17b-fp8-onprem/qr-rmsnorm-fusion__dTJLwbR/agent/trajectory.json` |  |
| `sglang-mmmu-ipc-crash` | 1 | `sglang-mmmu-ipc-crash__7mJpdM2` | `infra-bench/jobs/opencode-qwen3.5-397b-a17b-fp8-onprem/sglang-mmmu-ipc-crash__7mJpdM2/agent/trajectory.json` |  |
| `sglang-sync-stall` | 1 | `sglang-sync-stall__JUmsEsW` | `infra-bench/jobs/opencode-qwen3.5-397b-a17b-fp8-onprem/sglang-sync-stall__JUmsEsW/agent/trajectory.json` | `ApiRateLimitError` |
| `triton-matmul-tuning` | 0 | `triton-matmul-tuning__ptc5dmN` | `infra-bench/jobs/opencode-qwen3.5-397b-a17b-fp8-onprem/triton-matmul-tuning__ptc5dmN/agent/trajectory.json` |  |
| `vllm-aiter-debug` | 0 | `vllm-aiter-debug__c2fbaYk` | `infra-bench/jobs/opencode-qwen3.5-397b-a17b-fp8-onprem/vllm-aiter-debug__c2fbaYk/agent/trajectory.json` | `NetworkConnectionError` |

## Round 8 Results

Run date: 2026-07-20

Round 8 adds an on-prem OpenCode sweep for `MiMo-V2-Flash`. The model is served
by SGLang from
`/home/xisun/InfraBench/mimo-v2-flash-sgl/launch_sgl_mimo_v2_flash_server.sh` on
another MI350 machine at `http://10.145.64.81:30000/v1`. SGLang advertises the
model id `/models/MiMo-V2-Flash`, so OpenCode must request that exact served
model id.

Pricing was configured from the LiteLLM `openrouter/xiaomi/mimo-v2-flash`
reference: `$0.10/M` input, `$0.30/M` output, and `$0.01/M` cache-read tokens.
The completed smoke and full sweep both reported zero cache tokens.

### Round 8 Smoke Test

Smoke command:

```bash
JOB_NAME=smoke-opencode-mimo-v2-flash-onprem \
  MODEL=/models/MiMo-V2-Flash \
  AMD_OPENCODE_PROVIDER=onprem \
  AMD_CODEX_BASE_URL=http://10.145.64.81:30000/v1 \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' \
  INFRABENCH_GPU_COUNT=6 \
  ./run_open_code.sh -i hello-rocm
```

Smoke result summary:

```text
Trials: 1
Exceptions: 0
Reward 1.0: 1
Reward 0.0: 0
Cost USD: 0.002461
Input tokens: 23693
Cache tokens: 0
Output tokens: 307
Total runtime: 42s
Results written to /home/xisun/InfraBench/infra-bench/jobs/smoke-opencode-mimo-v2-flash-onprem/result.json
Run log: /home/xisun/InfraBench/infra-bench/jobs/smoke-opencode-mimo-v2-flash-onprem/run.log
```

### `MiMo-V2-Flash` via OpenCode On-Prem

Full sweep command:

```bash
JOB_NAME=opencode-mimo-v2-flash-onprem \
  MODEL=/models/MiMo-V2-Flash \
  AMD_OPENCODE_PROVIDER=onprem \
  AMD_CODEX_BASE_URL=http://10.145.64.81:30000/v1 \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' \
  INFRA_PARALLEL=4 \
  INFRABENCH_GPU_COUNT=6 \
  ./run_open_code.sh
```

Full result summary:

```text
Trials: 20
Exceptions: 4
Reward 1.0: 3
Reward 0.0: 17
Mean reward: 0.150
Total runtime: 2h 15m 43s
Cost USD: 15.651414
Median agent execution: 3m 56s
Input tokens: 155754490
Cache tokens: 0
Output tokens: 253215
Results written to /home/xisun/InfraBench/infra-bench/jobs/opencode-mimo-v2-flash-onprem/result.json
Run log: /home/xisun/InfraBench/infra-bench/jobs/opencode-mimo-v2-flash-onprem/run.log
```

Exception counts: `AgentTimeoutError`=3, `NonZeroAgentExitCodeError`=1.

All 20 trials have structured `agent/trajectory.json` files and raw OpenCode
event logs at `agent/opencode.txt`. The `engram-triton-kernel` trial uses a
reconstructed partial trajectory because the OpenCode JSON stream ended before a
complete `step_finish` event. The saved JSON artifacts were checked after the
run, and the live gateway key is not present.

Display metadata was normalized before documenting the result:
`stats.evals=opencode__MiMo-V2-Flash__infra-bench`, trial
`agent_info.model_info.name=MiMo-V2-Flash`, and saved run config
`config.agent.model_name=onprem/models/MiMo-V2-Flash`. The on-prem provider
config still includes the runtime `models/MiMo-V2-Flash` key so OpenCode can
route to the served SGLang model id.

Scoreboard: **3/20 passed**.

Harbor upload: private job `736b9f10-f93d-4282-b2af-8924659430cd`, uploaded
with `harbor upload /home/xisun/InfraBench/infra-bench/jobs/opencode-mimo-v2-flash-onprem`
on 2026-07-20. Hub URL:
`https://hub.harborframework.com/jobs/736b9f10-f93d-4282-b2af-8924659430cd`.

| Task | Reward | Trial | Trajectory/log | Exception |
|---|---:|---|---|---|
| `cute-layout-composition` | 0 | `cute-layout-composition__DnyF38K` | `infra-bench/jobs/opencode-mimo-v2-flash-onprem/cute-layout-composition__DnyF38K/agent/trajectory.json` |  |
| `dwconv3d-occupancy` | 0 | `dwconv3d-occupancy__jsh24bq` | `infra-bench/jobs/opencode-mimo-v2-flash-onprem/dwconv3d-occupancy__jsh24bq/agent/trajectory.json` |  |
| `engram-triton-kernel` | 0 | `engram-triton-kernel__VaqJPF3` | `infra-bench/jobs/opencode-mimo-v2-flash-onprem/engram-triton-kernel__VaqJPF3/agent/trajectory.json` | `AgentTimeoutError` |
| `flydsl-cdna4-preshuffle-gemm` | 0 | `flydsl-cdna4-preshuffle-gemm__RULXJhh` | `infra-bench/jobs/opencode-mimo-v2-flash-onprem/flydsl-cdna4-preshuffle-gemm__RULXJhh/agent/trajectory.json` |  |
| `gemm-fp8-ptpc-quant` | 0 | `gemm-fp8-ptpc-quant__ZVV33Db` | `infra-bench/jobs/opencode-mimo-v2-flash-onprem/gemm-fp8-ptpc-quant__ZVV33Db/agent/trajectory.json` |  |
| `gemma4-gemm-tuning` | 0 | `gemma4-gemm-tuning__Eo6utwm` | `infra-bench/jobs/opencode-mimo-v2-flash-onprem/gemma4-gemm-tuning__Eo6utwm/agent/trajectory.json` |  |
| `gemma4-sglang-serving-opt` | 0 | `gemma4-sglang-serving-opt__VHpwMcF` | `infra-bench/jobs/opencode-mimo-v2-flash-onprem/gemma4-sglang-serving-opt__VHpwMcF/agent/trajectory.json` | `AgentTimeoutError` |
| `gluon-a8w8-mfma-att` | 1 | `gluon-a8w8-mfma-att__t5rwo77` | `infra-bench/jobs/opencode-mimo-v2-flash-onprem/gluon-a8w8-mfma-att__t5rwo77/agent/trajectory.json` |  |
| `hello-rocm` | 1 | `hello-rocm__8hPS88A` | `infra-bench/jobs/opencode-mimo-v2-flash-onprem/hello-rocm__8hPS88A/agent/trajectory.json` |  |
| `hotspot-analysis-torch-profiler` | 0 | `hotspot-analysis-torch-profiler__AqqFfH9` | `infra-bench/jobs/opencode-mimo-v2-flash-onprem/hotspot-analysis-torch-profiler__AqqFfH9/agent/trajectory.json` | `NonZeroAgentExitCodeError` |
| `llm-fp8-quantize` | 0 | `llm-fp8-quantize__X9PAV2d` | `infra-bench/jobs/opencode-mimo-v2-flash-onprem/llm-fp8-quantize__X9PAV2d/agent/trajectory.json` |  |
| `llvm-simple-constant-propagation` | 0 | `llvm-simple-constant-propagation__G8rcjAp` | `infra-bench/jobs/opencode-mimo-v2-flash-onprem/llvm-simple-constant-propagation__G8rcjAp/agent/trajectory.json` |  |
| `mem-bandwidth-bench` | 0 | `mem-bandwidth-bench__iNCtPqN` | `infra-bench/jobs/opencode-mimo-v2-flash-onprem/mem-bandwidth-bench__iNCtPqN/agent/trajectory.json` | `AgentTimeoutError` |
| `paged-attention-hd256` | 0 | `paged-attention-hd256__JzbwhSr` | `infra-bench/jobs/opencode-mimo-v2-flash-onprem/paged-attention-hd256__JzbwhSr/agent/trajectory.json` |  |
| `pointnet2-hipify` | 0 | `pointnet2-hipify__w8HVMcd` | `infra-bench/jobs/opencode-mimo-v2-flash-onprem/pointnet2-hipify__w8HVMcd/agent/trajectory.json` |  |
| `qr-rmsnorm-fusion` | 0 | `qr-rmsnorm-fusion__Z2p5hmg` | `infra-bench/jobs/opencode-mimo-v2-flash-onprem/qr-rmsnorm-fusion__Z2p5hmg/agent/trajectory.json` |  |
| `sglang-mmmu-ipc-crash` | 0 | `sglang-mmmu-ipc-crash__WnBDEsW` | `infra-bench/jobs/opencode-mimo-v2-flash-onprem/sglang-mmmu-ipc-crash__WnBDEsW/agent/trajectory.json` |  |
| `sglang-sync-stall` | 0 | `sglang-sync-stall__Bt5cyUP` | `infra-bench/jobs/opencode-mimo-v2-flash-onprem/sglang-sync-stall__Bt5cyUP/agent/trajectory.json` |  |
| `triton-matmul-tuning` | 1 | `triton-matmul-tuning__baacYnF` | `infra-bench/jobs/opencode-mimo-v2-flash-onprem/triton-matmul-tuning__baacYnF/agent/trajectory.json` |  |
| `vllm-aiter-debug` | 0 | `vllm-aiter-debug__SSgnByY` | `infra-bench/jobs/opencode-mimo-v2-flash-onprem/vllm-aiter-debug__SSgnByY/agent/trajectory.json` |  |

## Round 9 Results

Run date: 2026-07-20 to 2026-07-21

Round 9 adds an on-prem OpenCode sweep for `Qwen3.5-122B-A10B-FP8`. The model is
served by SGLang from
`/home/xisun/InfraBench/qwen3.5-122b-sgl/launch_sgl_qwen3.5_122b_server.sh` on
another MI350 machine at `http://10.145.64.87:30000/v1`. SGLang advertises the
model id `/models/Qwen3.5-122B-A10B-FP8`, so OpenCode must request that exact
served model id. The run used `INFRABENCH_GPU_COUNT=6` because the on-prem
server uses GPUs 6 and 7.

Pricing was configured from the LiteLLM `openrouter/qwen/qwen3.5-122b-a10b`
reference: `$0.40/M` input, `$2.00/M` output, and `$0.40/M` cache-read tokens.

### Round 9 Smoke Tests

Initial smoke and post-restart smoke both passed `hello-rocm`:

| Job | Trial | Reward | Runtime | Notes |
|---|---|---:|---|---|
| `smoke-opencode-qwen3.5-122b-a10b-fp8-onprem` | `hello-rocm__mmfs9b7` | 1 | 48s | Initial endpoint check passed. |
| `smoke-opencode-qwen3.5-122b-a10b-fp8-onprem-restart` | `hello-rocm__DqCRHvy` | 1 | 43s | Passed after the first server restart. |

Smoke command shape:

```bash
JOB_NAME=smoke-opencode-qwen3.5-122b-a10b-fp8-onprem \
  MODEL=/models/Qwen3.5-122B-A10B-FP8 \
  AMD_OPENCODE_PROVIDER=onprem \
  AMD_CODEX_BASE_URL=http://10.145.64.87:30000/v1 \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' \
  INFRABENCH_GPU_COUNT=6 \
  ./run_open_code.sh -i hello-rocm
```

### `Qwen3.5-122B-A10B-FP8` via OpenCode On-Prem

Full sweep command used for the durable run:

```bash
JOB_NAME=opencode-qwen3.5-122b-a10b-fp8-onprem \
  MODEL=/models/Qwen3.5-122B-A10B-FP8 \
  AMD_OPENCODE_PROVIDER=onprem \
  AMD_CODEX_BASE_URL=http://10.145.64.87:30000/v1 \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' \
  INFRA_PARALLEL=2 \
  INFRABENCH_GPU_COUNT=6 \
  ./run_open_code.sh
```

This sweep is **not uploadable yet**. It was stopped on 2026-07-21 after the
on-prem endpoint stopped producing chat completions. A one-token
`/v1/chat/completions` probe against `/models/Qwen3.5-122B-A10B-FP8` timed out
after 45 seconds with no bytes received, even though `/v1/models` still returned
the expected served model id. To avoid converting the remaining trials into idle
timeouts, the tmux sweep `infrabench_qwen122_20260721` was stopped and stale
OpenCode processes were terminated. A final one-token probe after all task
containers had stopped also timed out after 45 seconds, confirming the blocker is
the on-prem generation endpoint rather than active InfraBench clients.

Current partial job:

```text
Job path: infra-bench/jobs/opencode-qwen3.5-122b-a10b-fp8-onprem
Job id: 296743c2-2768-40ea-9704-7c08cbb3132c
Started: 2026-07-20T19:46:36.327560
Last update: 2026-07-21T02:07:14.451312Z
Finished: null
Trials: 20
Completed trial records: 10
Errored trial records: 6
Running: 0
Pending: 10
Cancelled: 2
Cost USD: 0.8192468
Input tokens: 1874292
Cache tokens: 0
Output tokens: 34765
Trajectory files present: 6
```

Earlier invalid attempts are preserved separately:

- `infra-bench/jobs/opencode-qwen3.5-122b-a10b-fp8-onprem_servercrash-timeout_20260720223413`
- `infra-bench/jobs/opencode-qwen3.5-122b-a10b-fp8-onprem_interrupted-partial_20260721004544`

Partial finalized trials in the current directory:

| Task | Reward | Trial | Trajectory/log | Exception |
|---|---:|---|---|---|
| `dwconv3d-occupancy` | 0 | `dwconv3d-occupancy__F92vqBm` | `infra-bench/jobs/opencode-qwen3.5-122b-a10b-fp8-onprem/dwconv3d-occupancy__F92vqBm/agent/trajectory.json` |  |
| `flydsl-cdna4-preshuffle-gemm` | 0 | `flydsl-cdna4-preshuffle-gemm__vdUUETH` | `infra-bench/jobs/opencode-qwen3.5-122b-a10b-fp8-onprem/flydsl-cdna4-preshuffle-gemm__vdUUETH/agent/trajectory.json` | `NonZeroAgentExitCodeError` from manual stale-process termination |
| `gemm-fp8-ptpc-quant` | 0 | `gemm-fp8-ptpc-quant__TL9vJAN` | `infra-bench/jobs/opencode-qwen3.5-122b-a10b-fp8-onprem/gemm-fp8-ptpc-quant__TL9vJAN/agent/trajectory.json` |  |
| `gemma4-gemm-tuning` | 0 | `gemma4-gemm-tuning__RYCUhDe` | `infra-bench/jobs/opencode-qwen3.5-122b-a10b-fp8-onprem/gemma4-gemm-tuning__RYCUhDe/agent/trajectory.json` |  |
| `gemma4-sglang-serving-opt` | 0 | `gemma4-sglang-serving-opt__TdidQZY` | `infra-bench/jobs/opencode-qwen3.5-122b-a10b-fp8-onprem/gemma4-sglang-serving-opt__TdidQZY/agent/opencode.txt` | `NonZeroAgentExitCodeError` after server crash/stale request |
| `hotspot-analysis-torch-profiler` | 0 | `hotspot-analysis-torch-profiler__RRrGu2p` | `infra-bench/jobs/opencode-qwen3.5-122b-a10b-fp8-onprem/hotspot-analysis-torch-profiler__RRrGu2p/agent/trajectory.json` | `NonZeroAgentExitCodeError` |
| `llm-fp8-quantize` | n/a | `llm-fp8-quantize__vG93QTM` | `infra-bench/jobs/opencode-qwen3.5-122b-a10b-fp8-onprem/llm-fp8-quantize__vG93QTM/agent/opencode.txt` | `NonZeroAgentExitCodeError` from manual stale-process termination |
| `llvm-simple-constant-propagation` | n/a | `llvm-simple-constant-propagation__otr3bVy` | `infra-bench/jobs/opencode-qwen3.5-122b-a10b-fp8-onprem/llvm-simple-constant-propagation__otr3bVy/agent/opencode.txt` | `CancelledError` when sweep was stopped |
| `pointnet2-hipify` | 0 | `pointnet2-hipify__QPMRBjE` | `infra-bench/jobs/opencode-qwen3.5-122b-a10b-fp8-onprem/pointnet2-hipify__QPMRBjE/agent/opencode.txt` | `NonZeroAgentExitCodeError` from manual stale-process termination |
| `qr-rmsnorm-fusion` | 0 | `qr-rmsnorm-fusion__5C2HU3q` | `infra-bench/jobs/opencode-qwen3.5-122b-a10b-fp8-onprem/qr-rmsnorm-fusion__5C2HU3q/agent/trajectory.json` |  |

Recovery requirement: restart or fix the on-prem server until a one-token
`/v1/chat/completions` probe returns normally, then run a recovery subset for
the 14 non-uploadable or missing tasks before merging into an uploadable 20-task
job. At minimum this includes the 10 pending tasks plus
`gemma4-sglang-serving-opt`, `llm-fp8-quantize`, `llvm-simple-constant-propagation`,
and `pointnet2-hipify`.

## Round 10 Results

Run date: 2026-07-21

Round 10 adds an on-prem OpenCode sweep for `MiMo-V2.5-Pro`. The model is served
by SGLang from
`/home/xisun/InfraBench/mimo-v2.5-pro-sgl/launch_sgl_mimo_v2.5_pro_server.sh`
on another MI350X machine at `http://10.145.64.81:30000/v1`. SGLang advertises
the served model id `/models/MiMo-V2.5-Pro`, so OpenCode used that exact
`MODEL=` value. The run used `INFRABENCH_GPU_COUNT=6`.

Endpoint checks passed before the full sweep. The ping log
`mimo-v2.5-pro-sgl/sglang_ping.log` returned `pong`, and the GSM8K check in
`mimo-v2.5-pro-sgl/sgl_gms8k.log` reported 200 examples, 98.00% score, 72.6s,
1385 tok/s, and 101K tokens.

Pricing was configured from the LiteLLM `openrouter/xiaomi/mimo-v2.5-pro`
reference: `$1.00/M` input, `$3.00/M` output, and `$0.20/M` cache-read tokens.
The completed full sweep reported zero cache tokens.

### `MiMo-V2.5-Pro` via OpenCode On-Prem

Full sweep command:

```bash
JOB_NAME=opencode-mimo-v2.5-pro-onprem \
  MODEL=/models/MiMo-V2.5-Pro \
  AMD_OPENCODE_PROVIDER=onprem \
  AMD_CODEX_BASE_URL=http://10.145.64.81:30000/v1 \
  AMD_OPENCODE_NPM='@ai-sdk/openai-compatible' \
  INFRA_PARALLEL=4 \
  INFRABENCH_GPU_COUNT=6 \
  ./run_open_code.sh
```

Full result summary:

```text
Trials: 20
Exceptions: 5
Reward 1.0: 8
Reward 0.0: 12
Mean reward: 0.400
Total runtime: 2h 47m 33s
Cost USD: 11.951636
Median agent execution: 9m 21s
Input tokens: 10921157
Cache tokens: 0
Output tokens: 343493
Results written to /home/xisun/InfraBench/infra-bench/jobs/opencode-mimo-v2.5-pro-onprem/result.json
Run log: /home/xisun/InfraBench/infra-bench/jobs/opencode-mimo-v2.5-pro-onprem/run.log
```

Exception counts: `AgentTimeoutError`=4, `NonZeroAgentExitCodeError`=1.

All 20 trials have structured `agent/trajectory.json` files and raw OpenCode
event logs at `agent/opencode.txt`. Display metadata was normalized after the
run: `stats.evals=opencode__MiMo-V2.5-Pro__infra-bench`, trial
`agent_info.model_info.name=MiMo-V2.5-Pro`, and saved run config
`config.agent.model_name=onprem/models/MiMo-V2.5-Pro`. The on-prem provider
config still keeps the runtime `models/MiMo-V2.5-Pro` key for SGLang routing.

Scoreboard: **8/20 passed**.

| Task | Reward | Trial | Trajectory/log | Exception |
|---|---:|---|---|---|
| `cute-layout-composition` | 0 | `cute-layout-composition__MqjHUA2` | `infra-bench/jobs/opencode-mimo-v2.5-pro-onprem/cute-layout-composition__MqjHUA2/agent/trajectory.json` |  |
| `dwconv3d-occupancy` | 0 | `dwconv3d-occupancy__bqk9Nrb` | `infra-bench/jobs/opencode-mimo-v2.5-pro-onprem/dwconv3d-occupancy__bqk9Nrb/agent/trajectory.json` |  |
| `engram-triton-kernel` | 0 | `engram-triton-kernel__YGrTR98` | `infra-bench/jobs/opencode-mimo-v2.5-pro-onprem/engram-triton-kernel__YGrTR98/agent/trajectory.json` | `AgentTimeoutError` |
| `flydsl-cdna4-preshuffle-gemm` | 0 | `flydsl-cdna4-preshuffle-gemm__VfVgrQc` | `infra-bench/jobs/opencode-mimo-v2.5-pro-onprem/flydsl-cdna4-preshuffle-gemm__VfVgrQc/agent/trajectory.json` | `AgentTimeoutError` |
| `gemm-fp8-ptpc-quant` | 0 | `gemm-fp8-ptpc-quant__TdSQYni` | `infra-bench/jobs/opencode-mimo-v2.5-pro-onprem/gemm-fp8-ptpc-quant__TdSQYni/agent/trajectory.json` |  |
| `gemma4-gemm-tuning` | 0 | `gemma4-gemm-tuning__QJwwuPN` | `infra-bench/jobs/opencode-mimo-v2.5-pro-onprem/gemma4-gemm-tuning__QJwwuPN/agent/trajectory.json` |  |
| `gemma4-sglang-serving-opt` | 0 | `gemma4-sglang-serving-opt__LnezgTm` | `infra-bench/jobs/opencode-mimo-v2.5-pro-onprem/gemma4-sglang-serving-opt__LnezgTm/agent/trajectory.json` | `AgentTimeoutError` |
| `gluon-a8w8-mfma-att` | 1 | `gluon-a8w8-mfma-att__GHMuVZA` | `infra-bench/jobs/opencode-mimo-v2.5-pro-onprem/gluon-a8w8-mfma-att__GHMuVZA/agent/trajectory.json` |  |
| `hello-rocm` | 1 | `hello-rocm__fM5KjSb` | `infra-bench/jobs/opencode-mimo-v2.5-pro-onprem/hello-rocm__fM5KjSb/agent/trajectory.json` |  |
| `hotspot-analysis-torch-profiler` | 0 | `hotspot-analysis-torch-profiler__3P6xf8i` | `infra-bench/jobs/opencode-mimo-v2.5-pro-onprem/hotspot-analysis-torch-profiler__3P6xf8i/agent/trajectory.json` |  |
| `llm-fp8-quantize` | 0 | `llm-fp8-quantize__DuLKNhi` | `infra-bench/jobs/opencode-mimo-v2.5-pro-onprem/llm-fp8-quantize__DuLKNhi/agent/trajectory.json` | `AgentTimeoutError` |
| `llvm-simple-constant-propagation` | 1 | `llvm-simple-constant-propagation__5DvM9XC` | `infra-bench/jobs/opencode-mimo-v2.5-pro-onprem/llvm-simple-constant-propagation__5DvM9XC/agent/trajectory.json` |  |
| `mem-bandwidth-bench` | 1 | `mem-bandwidth-bench__cWBqVjV` | `infra-bench/jobs/opencode-mimo-v2.5-pro-onprem/mem-bandwidth-bench__cWBqVjV/agent/trajectory.json` |  |
| `paged-attention-hd256` | 0 | `paged-attention-hd256__xiVbgMw` | `infra-bench/jobs/opencode-mimo-v2.5-pro-onprem/paged-attention-hd256__xiVbgMw/agent/trajectory.json` |  |
| `pointnet2-hipify` | 1 | `pointnet2-hipify__GpVbmT2` | `infra-bench/jobs/opencode-mimo-v2.5-pro-onprem/pointnet2-hipify__GpVbmT2/agent/trajectory.json` |  |
| `qr-rmsnorm-fusion` | 0 | `qr-rmsnorm-fusion__5G6qLBM` | `infra-bench/jobs/opencode-mimo-v2.5-pro-onprem/qr-rmsnorm-fusion__5G6qLBM/agent/trajectory.json` |  |
| `sglang-mmmu-ipc-crash` | 1 | `sglang-mmmu-ipc-crash__3jXvME4` | `infra-bench/jobs/opencode-mimo-v2.5-pro-onprem/sglang-mmmu-ipc-crash__3jXvME4/agent/trajectory.json` |  |
| `sglang-sync-stall` | 1 | `sglang-sync-stall__CwkarbX` | `infra-bench/jobs/opencode-mimo-v2.5-pro-onprem/sglang-sync-stall__CwkarbX/agent/trajectory.json` |  |
| `triton-matmul-tuning` | 0 | `triton-matmul-tuning__hBCXcWk` | `infra-bench/jobs/opencode-mimo-v2.5-pro-onprem/triton-matmul-tuning__hBCXcWk/agent/trajectory.json` |  |
| `vllm-aiter-debug` | 1 | `vllm-aiter-debug__e7wWBNb` | `infra-bench/jobs/opencode-mimo-v2.5-pro-onprem/vllm-aiter-debug__e7wWBNb/agent/trajectory.json` | `NonZeroAgentExitCodeError` |

## Analyzer Runs

### Claude Opus 4.8 Review of Codex GPT Jobs

Run date: 2026-07-21

Evaluator command shape:

```bash
MODEL=claude-opus-4.8 ./analyze.sh infra-bench/jobs/<codex-gpt-job>
```

The analyzer pass covered all job directories with the `codex-gpt` prefix:
`codex-gpt-5.5`, `codex-gpt-5.6-luna`, `codex-gpt-5.6-sol`, and
`codex-gpt-5.6-terra`. The first Terra analyzer run hit one
`AgentSetupTimeoutError` on the `triton-matmul-tuning` analysis task, so that
single analysis task was rerun separately and completed.

| Source job | Analyzer job | Completed | Errors | Cost USD |
|---|---|---:|---:|---:|
| `codex-gpt-5.5` | `infra-bench/jobs/analysis-codex-gpt-5.5-claude-opus-4.8-20260721_095608` | 20 | 0 | 50.764920 |
| `codex-gpt-5.6-luna` | `infra-bench/jobs/analysis-codex-gpt-5.6-luna-claude-opus-4.8-20260721_095608` | 20 | 0 | 51.339033 |
| `codex-gpt-5.6-sol` | `infra-bench/jobs/analysis-codex-gpt-5.6-sol-claude-opus-4.8-20260721_095608` | 20 | 0 | 52.055084 |
| `codex-gpt-5.6-terra` | `infra-bench/jobs/analysis-codex-gpt-5.6-terra-claude-opus-4.8-20260721_095608` | 20 | 1 | 44.508895 |
| `codex-gpt-5.6-terra` retry | `infra-bench/jobs/analysis-codex-gpt-5.6-terra-triton-retry-claude-opus-4.8-20260721_124054` | 1 | 0 | 2.607569 |

Total analyzer cost including the Terra retry was `201.2755005` USD. Across the
completed analyzer artifacts, all checks passed except one substantive finding:

| Source job | Source task | Analyzer trial | `reward_hacking` | `task_specification` | Notes |
|---|---|---|---|---|---|
| `codex-gpt-5.6-luna` | `gemm-fp8-ptpc-quant` | `analysis-codex-gpt-5.6-luna-claude-opus-4.8-20260721_095608/analyze-gemm-fp8-ptpc-quant__Ru2__oGtvw7H` | fail | pass | The analyzer found that the agent located `/opt/reference/reference_ptpc.py`, read the frozen reference kernel, and copied its output-stage pattern after getting stuck on the multi-warp layout case. |

The Terra retry covers the missing `triton-matmul-tuning` analyzer task, so the
Codex GPT analyzer coverage is complete for the four source jobs.

### Codex GPT-5.6-Sol Review of Non-Codex Jobs

Run date: 2026-07-21 to 2026-07-22

Evaluator command shape:

```bash
MODEL=gpt-5.6-sol ./analyze.sh infra-bench/jobs/<non-codex-job>
```

This analyzer pass covered all current job directories except those with the
`codex-gpt` prefix, because the Codex GPT jobs were already reviewed by Claude
Opus 4.8 in the previous analyzer pass. The covered set includes the Claude
Code jobs and all OpenCode jobs present under `infra-bench/jobs`.

| Source job | Analyzer job | Completed | Errors | Cost USD |
|---|---|---:|---:|---:|
| `claude-haiku-4.5` | `infra-bench/jobs/analysis-claude-haiku-4.5-codex-gpt-5.6-sol-20260721_155359` | 20 | 0 | 18.421642 |
| `claude-opus-4.6` | `infra-bench/jobs/analysis-claude-opus-4.6-codex-gpt-5.6-sol-20260721_155359` | 20 | 0 | 18.830555 |
| `claude-opus-4.8` | `infra-bench/jobs/analysis-claude-opus-4.8-codex-gpt-5.6-sol-20260721_155359` | 20 | 0 | 12.491774 |
| `claude-sonnet-5` | `infra-bench/jobs/analysis-claude-sonnet-5-codex-gpt-5.6-sol-20260721_155359` | 20 | 0 | 15.862632 |
| `opencode-deepseek-v4-flash` | `infra-bench/jobs/analysis-opencode-deepseek-v4-flash-codex-gpt-5.6-sol-20260721_155359` | 20 | 0 | 15.348175 |
| `opencode-gemini-3.5-flash` | `infra-bench/jobs/analysis-opencode-gemini-3.5-flash-codex-gpt-5.6-sol-20260721_155359` | 20 | 0 | 18.709835 |
| `opencode-gemma-4-31b` | `infra-bench/jobs/analysis-opencode-gemma-4-31b-codex-gpt-5.6-sol-20260721_155359` | 20 | 0 | 14.815040 |
| `opencode-glm-5.2-fp8-onprem` | `infra-bench/jobs/analysis-opencode-glm-5.2-fp8-onprem-codex-gpt-5.6-sol-20260721_155359` | 20 | 0 | 21.527364 |
| `opencode-kimi-k2.6` | `infra-bench/jobs/analysis-opencode-kimi-k2.6-codex-gpt-5.6-sol-20260721_155359` | 20 | 0 | 17.844321 |
| `opencode-kimi-k2.7-code-onprem` | `infra-bench/jobs/analysis-opencode-kimi-k2.7-code-onprem-codex-gpt-5.6-sol-20260721_155359` | 20 | 0 | 25.457220 |
| `opencode-mimo-v2-flash-onprem` | `infra-bench/jobs/analysis-opencode-mimo-v2-flash-onprem-codex-gpt-5.6-sol-20260721_155359` | 20 | 0 | 21.309638 |
| `opencode-mimo-v2.5-pro-onprem` | `infra-bench/jobs/analysis-opencode-mimo-v2.5-pro-onprem-codex-gpt-5.6-sol-20260721_155359` | 20 | 0 | 20.673591 |
| `opencode-minimax-m2.7` | `infra-bench/jobs/analysis-opencode-minimax-m2.7-codex-gpt-5.6-sol-20260721_155359` | 20 | 0 | 19.310379 |
| `opencode-minimax-m3-onprem` | `infra-bench/jobs/analysis-opencode-minimax-m3-onprem-codex-gpt-5.6-sol-20260721_155359` | 20 | 0 | 18.905778 |
| `opencode-qwen3.5-397b-a17b-fp8-onprem` | `infra-bench/jobs/analysis-opencode-qwen3.5-397b-a17b-fp8-onprem-codex-gpt-5.6-sol-20260721_155359` | 20 | 0 | 19.034255 |
| `opencode-qwen3.6-35b-a3b` | `infra-bench/jobs/analysis-opencode-qwen3.6-35b-a3b-codex-gpt-5.6-sol-20260721_155359` | 20 | 0 | 18.043250 |
| `opencode-qwopus3.6-27b-coder-onprem` | `infra-bench/jobs/analysis-opencode-qwopus3.6-27b-coder-onprem-codex-gpt-5.6-sol-20260721_155359` | 20 | 0 | 19.433080 |
| `opencode-qwopus3.6-35b-a3b-coder-onprem` | `infra-bench/jobs/analysis-opencode-qwopus3.6-35b-a3b-coder-onprem-codex-gpt-5.6-sol-20260721_155359` | 20 | 0 | 14.585668 |

Total analyzer cost for this non-Codex pass was `330.604197` USD. All 18
analyzer jobs completed all 20 analysis trials with zero runner errors, and the
structured analyzer outputs did not report any `reward_hacking` or
`task_specification` failures.
