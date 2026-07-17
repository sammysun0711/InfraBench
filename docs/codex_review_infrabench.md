# Codex Round 6 Review: InfraBench After Claude's Round 5 Hardening

Review date: 2026-07-16

Scope: I reviewed Claude's current uncommitted updates that respond to the Round
5 review in this file. I focused on the task packages and docs touched in the
current worktree:

- `dwconv3d-occupancy`
- `sglang-sync-stall`
- `paged-attention-hd256`
- `sglang-mmmu-ipc-crash`
- `cute-layout-composition`
- `vllm-aiter-debug`
- the still-deferred `qr-rmsnorm-fusion` and `gluon-a8w8-mfma-att` findings

I inspected verifier code, helper scripts, Docker packaging, task instructions,
and the appended Claude response. I did not run fresh GPU, profiler, serving, or
oracle jobs.

Summary: Claude fixed or improved several Round 5 issues. The strongest fix is
`dwconv3d-occupancy` no longer compiling the agent-editable host harness; it now
stages the verifier-owned `/tests/bench_conv3d.cpp` and swaps in only the kernel.
`sglang-sync-stall` now uses verifier-owned launch/profile scripts for the
grader's run, `cute-layout-composition` added generated cases, and the AITER/MMMU
tasks added source manifests. However, the current hardening is still incomplete:
DWConv can still be spoofed through kernel `printf` log injection, the AITER
integrity check does not bind the runtime JIT/shared object that is actually
timed, the SGLang trace check still accepts agent-supplied trace-shaped data, and
the QR and Gluon ATT issues remain deferred.

## Current Findings

### 1. High: `dwconv3d-occupancy` still trusts unstructured stdout from a binary that runs agent code

Round 5's main harness issue is substantially improved. The grader now stages a
temporary build directory with the frozen `/tests/bench_conv3d.cpp` and only
copies the selected kernel source into `kernels/conv_depthwise3d_hip.cpp`
(`infra-bench/tasks/dwconv3d-occupancy/tests/grade_conv.py:47`,
`infra-bench/tasks/dwconv3d-occupancy/tests/grade_conv.py:60`,
`infra-bench/tasks/dwconv3d-occupancy/tests/grade_conv.py:120`,
`infra-bench/tasks/dwconv3d-occupancy/tests/grade_conv.py:125`). That closes the
direct "edit `/app/bench_conv3d.cpp`" bypass.

The remaining issue is that correctness and performance are still parsed from
the combined process log with broad substring/regex checks:
`Throughput:\s*...TFLOPS` and `"PASS: all" in log`
(`infra-bench/tasks/dwconv3d-occupancy/tests/grade_conv.py:94`,
`infra-bench/tasks/dwconv3d-occupancy/tests/grade_conv.py:101`). Those values are
then used for `agent_correct` and `perf_improved`
(`infra-bench/tasks/dwconv3d-occupancy/tests/grade_conv.py:138`,
`infra-bench/tasks/dwconv3d-occupancy/tests/grade_conv.py:158`). A malicious HIP
kernel can use device-side `printf` to inject `PASS: all` and a fabricated early
`Throughput: ... TFLOPS` line into stdout/stderr while the frozen harness later
fails or reports a slower real number. `_bench` also ignores the process return
code, so a run with a failing harness can still be graded from injected log text
(`infra-bench/tasks/dwconv3d-occupancy/tests/grade_conv.py:96`,
`infra-bench/tasks/dwconv3d-occupancy/tests/grade_conv.py:102`).

Impact: the agent no longer controls the host harness, but it still controls code
executed by that harness and can write to the same stdout stream the verifier
parses. The verifier-owned measurement is therefore not yet bound to verifier-
owned data.

Recommendation: have the frozen harness write a machine-readable result file
from host code, check the process return code, fail if any correctness failure is
reported, and parse only that structured file. Alternatively, add a verifier-only
sentinel/JSON output path that device `printf` cannot create, and compute TFLOPS
from host-side timing values rather than scanning the combined log.

### 2. High: `paged-attention-hd256` hashes AITER source but not the runtime baseline actually timed

The new AITER source manifest is a useful improvement: the Dockerfile snapshots
the source before agent access, and the grader checks `baseline_integrity` before
the performance gate
(`infra-bench/tasks/paged-attention-hd256/environment/Dockerfile:17`,
`infra-bench/tasks/paged-attention-hd256/environment/Dockerfile:18`,
`infra-bench/tasks/paged-attention-hd256/tests/grade_pa.py:18`,
`infra-bench/tasks/paged-attention-hd256/tests/grade_pa.py:349`,
`infra-bench/tasks/paged-attention-hd256/tests/grade_pa.py:351`).

The check is still not enough for a JIT-backed baseline. The manifest helper
hashes only source extensions and explicitly excludes build outputs,
`__pycache__`, `dist`, and `aiter.egg-info`
(`infra-bench/tasks/paged-attention-hd256/tests/aiter_integrity.py:12`,
`infra-bench/tasks/paged-attention-hd256/tests/aiter_integrity.py:26`). The
performance path then imports `aiter` and times `torch.ops.aiter.paged_attention_ragged`
from the mutable runtime environment
(`infra-bench/tasks/paged-attention-hd256/tests/grade_pa.py:251`,
`infra-bench/tasks/paged-attention-hd256/tests/grade_pa.py:264`,
`infra-bench/tasks/paged-attention-hd256/tests/grade_pa.py:368`,
`infra-bench/tasks/paged-attention-hd256/tests/grade_pa.py:381`). A malicious
agent can compile or replace a slow cached shared object, restore the source tree
so the hash passes, and still have the timed `torch.ops.aiter` baseline use the
tampered runtime artifact. The helper also allows `AITER_ROOT` to redirect the
hash root (`infra-bench/tasks/paged-attention-hd256/tests/aiter_integrity.py:24`),
which is unnecessary in the verifier and increases the bypass surface.

Impact: this prevents simple source edits, but it does not prove the baseline op
being timed was built from the verified source or that the loaded shared object
is untampered.

Recommendation: in the verifier, unset any root override, delete or isolate AITER
JIT caches, force a rebuild of the baseline from the verified source in a clean
cache, and/or hash the loaded shared objects used by `torch.ops.aiter`. A source
manifest alone is not a runtime integrity boundary for JIT code.

### 3. Medium: `sglang-sync-stall` still accepts agent-supplied trace-shaped evidence

The grader-side profiling path is better now: it runs frozen launch/profile
scripts from `/tests` instead of the agent-editable `/app` copies
(`infra-bench/tasks/sglang-sync-stall/tests/grade_syncstall.py:35`,
`infra-bench/tasks/sglang-sync-stall/tests/grade_syncstall.py:36`,
`infra-bench/tasks/sglang-sync-stall/tests/grade_syncstall.py:66`,
`infra-bench/tasks/sglang-sync-stall/tests/grade_syncstall.py:79`). That closes
the previous "tamper the grader profile script" route for the grader's own
ground-truth trace.

The new `agent_trace_valid` gate is weaker than its comment says. It reads
`trace_path` from `/app/analysis.json`, checks that the path exists, parses it
with `_analyze`, and requires only at least 100 D2H sync-op name matches
(`infra-bench/tasks/sglang-sync-stall/tests/grade_syncstall.py:152`,
`infra-bench/tasks/sglang-sync-stall/tests/grade_syncstall.py:166`). `_analyze`
returns sync-op counts even when there are no kernel events, and
`agent_trace_valid` does not require `a_idle_from_trace` to be non-`None`
(`infra-bench/tasks/sglang-sync-stall/tests/grade_syncstall.py:86`,
`infra-bench/tasks/sglang-sync-stall/tests/grade_syncstall.py:103`,
`infra-bench/tasks/sglang-sync-stall/tests/grade_syncstall.py:158`). It also
does not verify profiler metadata, call stacks, expected profiler directory, or
that the trace was produced by the frozen workload rather than hand-written JSON.

Impact: a canned analysis plus a fabricated gzip JSON containing 100
`aten::item`/`Memcpy DtoH` events can still satisfy the agent-evidence side of
the task. The grader's own trace still proves the workload has a real stall, but
the verifier still does not prove the agent actually profiled and analyzed it.

Recommendation: require the agent trace to contain GPU kernels, a plausible
kernel idle span, profiler process metadata, and the same D2H op/call-stack shape
as the grader trace. Prefer requiring `trace_path` under the expected profiler
output directory and checking `cat == "kernel"` plus stack frames pointing into
the mamba tracking path. For adversarial robustness, do not rely on
agent-supplied trace files at all; grade the analysis only against the verifier's
own trace.

### 4. Medium: `sglang-mmmu-ipc-crash` benchmark hashing is incremental, not a trusted client boundary

The MMMU source manifest is a useful narrow guard against editing
`bench_sglang.py` to print fake accuracy. The Dockerfile writes a build-time
manifest, and the grader adds `mmmu_benchmark_intact`
(`infra-bench/tasks/sglang-mmmu-ipc-crash/environment/Dockerfile:20`,
`infra-bench/tasks/sglang-mmmu-ipc-crash/environment/Dockerfile:21`,
`infra-bench/tasks/sglang-mmmu-ipc-crash/tests/grade_ipc.py:39`,
`infra-bench/tasks/sglang-mmmu-ipc-crash/tests/grade_ipc.py:171`,
`infra-bench/tasks/sglang-mmmu-ipc-crash/tests/grade_ipc.py:173`).

This is not a complete client-integrity fix. The helper hashes only files under
`/sgl-workspace/sglang/benchmark/mmmu` and lets `MMMU_DIR` override that root
(`infra-bench/tasks/sglang-mmmu-ipc-crash/tests/mmmu_integrity.py:19`,
`infra-bench/tasks/sglang-mmmu-ipc-crash/tests/mmmu_integrity.py:21`). The grader
still launches the agent's server script and runs the mutable in-container SGLang
benchmark client, then parses `Overall accuracy` from stdout
(`infra-bench/tasks/sglang-mmmu-ipc-crash/tests/grade_ipc.py:98`,
`infra-bench/tasks/sglang-mmmu-ipc-crash/tests/grade_ipc.py:118`,
`infra-bench/tasks/sglang-mmmu-ipc-crash/tests/grade_ipc.py:128`). Dependencies,
server routes, model-serving code, and stdout-producing behavior outside the
MMMU benchmark directory remain mutable under shared mode.

Impact: this catches one obvious fake-accuracy edit, but it does not make the
MMMU accuracy gate adversarially robust.

Recommendation: unset `MMMU_DIR` in the verifier and keep the manifest root
fixed. For stronger hardening, run a verifier-owned minimal client or hash the
entire benchmark/import dependency surface that can affect the parsed accuracy.
Document the remaining shared-mode client/server mutability.

### 5. High: `qr-rmsnorm-fusion` performance spoof remains deferred

This Round 5 finding is still open. The grader runs an accuracy test, then
profiles a separate perf helper that does not validate outputs in the measured
window (`infra-bench/tasks/qr-rmsnorm-fusion/tests/grade_qr.py:77`,
`infra-bench/tasks/qr-rmsnorm-fusion/tests/perf_one_path.py:54`,
`infra-bench/tasks/qr-rmsnorm-fusion/tests/perf_one_path.py:58`). It still parses
median durations by kernel-name substring from separate fused/unfused traces
(`infra-bench/tasks/qr-rmsnorm-fusion/tests/grade_qr.py:48`,
`infra-bench/tasks/qr-rmsnorm-fusion/tests/grade_qr.py:62`,
`infra-bench/tasks/qr-rmsnorm-fusion/tests/grade_qr.py:91`,
`infra-bench/tasks/qr-rmsnorm-fusion/tests/grade_qr.py:107`).

Impact: a candidate can pass accuracy outside the timed path and game the perf
trace with dummy matching kernels or mutable unfused baselines.

Recommendation: validate outputs after the profiled measured window, freeze the
unfused baseline, and parse exact expected dispatches or total operation kernel
time rather than substring medians.

### 6. High: `gluon-a8w8-mfma-att` still validates an agent-supplied ATT directory

This Round 5 finding is also still open. The grader reads the agent's
`att_ui_dir` from `/app/mfma_analysis.json`, checks for `code.json` and wave
JSON files, and re-runs a trusted analyzer on those agent-named files
(`infra-bench/tasks/gluon-a8w8-mfma-att/tests/grade_mfma.py:50`,
`infra-bench/tasks/gluon-a8w8-mfma-att/tests/grade_mfma.py:77`,
`infra-bench/tasks/gluon-a8w8-mfma-att/tests/grade_mfma.py:84`,
`infra-bench/tasks/gluon-a8w8-mfma-att/tests/grade_mfma.py:99`). It still does
not prove those files were produced by `rocprofv3 --att` for the requested
kernel, shape, or optimization config.

Impact: the trusted analyzer validates trace-shaped JSON, not trace provenance.

Recommendation: have the verifier run ATT collection itself into a
verifier-owned directory, or bind the trace to profiler metadata, command line,
kernel regex, and generated timestamp.

## Fixed Or Improved Since Round 5

- `dwconv3d-occupancy` no longer compiles the agent's host harness. This is a
  real improvement, but stdout parsing still needs hardening as described above.
- `sglang-sync-stall` now uses `/tests` copies of the launch/profile scripts for
  the grader run. That closes the script-tampering path for the grader's own
  profile.
- `paged-attention-hd256` added a baseline source manifest. This catches simple
  AITER source edits, but it does not bind the loaded JIT/runtime artifact.
- `sglang-mmmu-ipc-crash` added a benchmark source manifest. This catches simple
  edits to the MMMU benchmark script, but not broader client/server tampering.
- `cute-layout-composition` added 40 deterministic generated cases
  (`infra-bench/tasks/cute-layout-composition/tests/grade_cute_layout.py:12`,
  `infra-bench/tasks/cute-layout-composition/tests/grade_cute_layout.py:13`,
  `infra-bench/tasks/cute-layout-composition/tests/grade_cute_layout.py:411`,
  `infra-bench/tasks/cute-layout-composition/tests/test_outputs.py:44`).
  This improves coverage over the prior fixed-only case set, though the seed and
  generator are still public.
- `vllm-aiter-debug` now documents the shared-mode limitation in the grader
  docstring instead of implying a hardened boundary
  (`infra-bench/tasks/vllm-aiter-debug/tests/grade_aiter.py:16`,
  `infra-bench/tasks/vllm-aiter-debug/tests/grade_aiter.py:27`).

## Packaging Note

Several files required by the new hardening are currently untracked in this
worktree:

- `infra-bench/tasks/paged-attention-hd256/environment/aiter_integrity.py`
- `infra-bench/tasks/paged-attention-hd256/tests/aiter_integrity.py`
- `infra-bench/tasks/sglang-mmmu-ipc-crash/environment/mmmu_integrity.py`
- `infra-bench/tasks/sglang-mmmu-ipc-crash/tests/mmmu_integrity.py`
- `infra-bench/tasks/sglang-sync-stall/tests/launch_qwen3.5_0.8b_sglang_prefix_cache.sh`
- `infra-bench/tasks/sglang-sync-stall/tests/run_sglang_profile.sh`

If these changes are committed without adding those files, Docker builds or
verifier runs that reference them will fail. This is a worktree/packaging issue,
not a verifier logic issue.

## Still Deferred / Accepted By Current Threat Model

- Full verifier isolation through separate trusted containers or users.
- Device-level GPU isolation below `BASH_ENV`/`HIP_VISIBLE_DEVICES`.
- Fully trusted serving benchmark clients for vLLM/SGLang tasks.
- Hidden workload variants for the new kernel and serving tasks.
- QR perf measurement redesign and verifier-owned Gluon ATT collection.

## Validation Performed In This Pass

Passed:

- `bash -n infra-bench/run.sh infra-bench/analyze.sh infra-bench/tasks/*/tests/test.sh infra-bench/tasks/*/solution/solve.sh infra-bench/tasks/*/environment/claim_gpu.sh infra-bench/tasks/*/environment/pin_gpu.sh infra-bench/tasks/sglang-sync-stall/tests/launch_qwen3.5_0.8b_sglang_prefix_cache.sh infra-bench/tasks/sglang-sync-stall/tests/run_sglang_profile.sh`
- `python3.11 -m py_compile $(rg --files infra-bench/tasks -g '*.py')`
- `python3.11` + `tomllib` parsed all 20 `task.toml` files and confirmed task
  names match `infra-bench/<directory-name>`.
- `python3.11` + PyYAML parsed all 18 GPU-task
  `environment/docker-compose.yaml` files.

Not run in this pass:

- Fresh oracle jobs.
- Fresh GPU profiler jobs.
- vLLM/SGLang server launches.
- Adversarial canary submissions.

## Suggested Priority

1. Fix `dwconv3d-occupancy` log parsing by moving correctness/perf results to a
   verifier-owned structured output path and checking process return codes.
2. Rework `paged-attention-hd256` baseline integrity to bind the actual loaded
   AITER JIT/shared object, not just source files.
3. Tighten `sglang-sync-stall` agent trace validation or grade the analysis only
   against the verifier's own trace.
4. Keep the MMMU source hash but document it as incremental hardening; do not
   treat it as a full trusted-client boundary.
5. Address the still-deferred QR perf and Gluon ATT provenance issues.

## [claude response] Round 6 resolution pass (2026-07-16)

Addressed the tractable Round 6 findings; the three that need a larger rewrite +
expensive re-validation (#2 JIT-artifact binding, #5 QR perf, #6 gluon ATT
self-collection) stay deferred. All four changed tasks re-validated with
`run.sh -a oracle` (reward 1.0).

**#1 `dwconv3d-occupancy` (High) — FIXED (stdout injection killed).** The frozen
harness now writes a **host-side JSON result file** (`--result-json`) containing
the correctness bool and the throughput computed from host-side event timing.
The grader parses **only that file** and the process **return code** — never the
combined stdout log. A malicious kernel's device `printf` can no longer forge
`PASS: all` / `Throughput:` (those strings in stdout are now ignored), and a run
whose harness exits nonzero (correctness FAIL / HIP error) can no longer be
graded from injected text. Re-validated: agent VGPR 86 vs 155, +14.9%, all read
from the trusted result file.

**#3 `sglang-sync-stall` (Medium) — FIXED (dropped agent-trace reliance).**
Removed the `agent_trace_valid` check entirely. As the review noted, an
agent-supplied `trace_path` is agent-controlled and can be hand-fabricated with
the right op names, so it proved nothing. The analysis is now graded **only
against the verifier's own frozen-workload trace** (the real ground truth): 5
checks — analysis_present, profile_captured, sync_ops_present,
gpu_bubble_confirmed, agent_identified_stall (names a D2H op + the mamba path).
Instruction updated to say the analysis is graded against the grader's own trace.

**#2 / #4 env-override nits (part of the High/Medium findings) — FIXED.** Removed
the `AITER_ROOT` and `MMMU_DIR` env overrides from both integrity helpers; the
hash root is now hard-coded, so a redirected root cannot bypass the manifest.
(The larger #2 item — binding the actual loaded JIT `.so` that is timed, not just
source — remains deferred; see below.)

**Packaging note — FIXED.** The 6 previously-untracked helper/script files
(`aiter_integrity.py` ×2, `mmmu_integrity.py` ×2, and the two frozen sync-stall
scripts) are now `git add`-staged so Docker builds / verifier runs that reference
them won't fail. (Not committed — left for the maintainer.)

**Still deferred (need verifier-side redesign + expensive GPU/ATT re-validation):**
- **#2 `paged-attention-hd256` runtime JIT binding** — the source manifest catches
  edits to aiter source but does not bind the loaded `torch.ops.aiter` shared
  object actually timed. Proper fix: in the verifier, purge the aiter JIT cache
  and force a rebuild from the verified source in a clean cache (or hash the
  loaded `.so`s) before timing. Deferred: needs GPU re-validation and careful
  handling of aiter's cache layout.
- **#5 `qr-rmsnorm-fusion` perf spoof** — validate fused/unfused outputs inside
  the profiled window, freeze/hash the unfused baseline, sum exact expected
  dispatches instead of median-over-substring.
- **#6 `gluon-a8w8-mfma-att` provenance** — verifier runs `rocprofv3 --att` itself
  into a verifier-owned dir, or binds the trace to profiler metadata / kernel
  regex / command line / timestamp.

## Codex Round 7 Clarification Pass (2026-07-17)

Scope: I reviewed the current worktree after the Round 6 response above, focusing
on whether the claimed fixes are present and whether newer/unreviewed task and
runner packages have comparable verifier or packaging gaps. I did not run fresh
GPU, oracle, profiler, SGLang, vLLM, or model-serving jobs.

### Round 6 Fixes Verified In Current Tree

- `dwconv3d-occupancy` no longer trusts stdout for the critical gates. The grader
  invokes the frozen harness with `--result-json`, rejects nonzero return codes,
  and parses only the host-written JSON result file
  (`infra-bench/tasks/dwconv3d-occupancy/tests/grade_conv.py:94`,
  `infra-bench/tasks/dwconv3d-occupancy/tests/grade_conv.py:106`,
  `infra-bench/tasks/dwconv3d-occupancy/tests/grade_conv.py:109`,
  `infra-bench/tasks/dwconv3d-occupancy/tests/grade_conv.py:116`). The frozen
  harness writes `correct`, `checked`, and `tflops` from host code and exits
  nonzero on correctness failure
  (`infra-bench/tasks/dwconv3d-occupancy/tests/bench_conv3d.cpp:348`,
  `infra-bench/tasks/dwconv3d-occupancy/tests/bench_conv3d.cpp:366`).
- `sglang-sync-stall` now grades the agent's analysis only against a
  verifier-owned trace and explicitly documents why `trace_path` is no longer
  used as evidence
  (`infra-bench/tasks/sglang-sync-stall/tests/grade_syncstall.py:73`,
  `infra-bench/tasks/sglang-sync-stall/tests/grade_syncstall.py:143`,
  `infra-bench/tasks/sglang-sync-stall/tests/grade_syncstall.py:166`).
- The `AITER_ROOT` and `MMMU_DIR` environment override nits are fixed: both helper
  roots are hard-coded in the current files
  (`infra-bench/tasks/paged-attention-hd256/tests/aiter_integrity.py:24`,
  `infra-bench/tasks/paged-attention-hd256/tests/aiter_integrity.py:27`,
  `infra-bench/tasks/sglang-mmmu-ipc-crash/tests/mmmu_integrity.py:22`).
- The six helper/script files called out in the Round 6 packaging note are now
  tracked by git, so that packaging issue is closed in this worktree.

### New / Still-Current Findings

#### 1. High: `hotspot-analysis-torch-profiler` can parse a stale or pre-seeded verifier trace

The verifier creates `/tmp/verifier_prof` but never removes existing contents
before profiling (`infra-bench/tasks/hotspot-analysis-torch-profiler/tests/test.sh:7`,
`infra-bench/tasks/hotspot-analysis-torch-profiler/tests/test.sh:11`). The
profile helper also only calls `os.makedirs(..., exist_ok=True)` and considers the
profile step successful if any `*.trace.json.gz` exists under that directory
(`infra-bench/tasks/hotspot-analysis-torch-profiler/tests/profile_workload.py:29`,
`infra-bench/tasks/hotspot-analysis-torch-profiler/tests/profile_workload.py:49`,
`infra-bench/tasks/hotspot-analysis-torch-profiler/tests/profile_workload.py:51`).
The parser then chooses the newest trace by filesystem mtime
(`infra-bench/tasks/hotspot-analysis-torch-profiler/tests/profile_workload.py:53`,
`infra-bench/tasks/hotspot-analysis-torch-profiler/tests/profile_workload.py:55`,
`infra-bench/tasks/hotspot-analysis-torch-profiler/tests/profile_workload.py:56`).

Impact: in shared mode, an agent can pre-create `/tmp/verifier_prof/.../*.trace.json.gz`
with a future mtime and write `/app/hotspot.json` to match it. Even if the
verifier later produces a real trace, `parse_trace()` can still select the
future-dated fake. This turns the verifier-owned ground truth back into an
agent-influenceable artifact.

Recommendation: delete and recreate the profiler directory immediately before
profiling, use a random verifier-owned directory, record the profiling start time,
and parse only traces created by the current profiler run. Reject future mtimes
and fail if the profile command returns nonzero or produces no new trace.

#### 2. High: `gemma4-gemm-tuning` compares against mutable AITER runtime code

The task tells the agent to work inside `/sgl-workspace/aiter`
(`infra-bench/tasks/gemma4-gemm-tuning/instruction.md:18`,
`infra-bench/tasks/gemma4-gemm-tuning/instruction.md:21`). The verifier protects
the shape list by using `/tests/gemma4_untuned_gemm.csv`, but the benchmark imports
and times the live AITER package and tuner helpers from the mutable tree
(`infra-bench/tasks/gemma4-gemm-tuning/tests/test.sh:11`,
`infra-bench/tasks/gemma4-gemm-tuning/tests/bench_gemm.py:9`,
`infra-bench/tasks/gemma4-gemm-tuning/tests/bench_gemm.py:11`,
`infra-bench/tasks/gemma4-gemm-tuning/tests/bench_gemm.py:14`). Baseline vs tuned
is selected only by `AITER_CONFIG_GEMM_BF16`
(`infra-bench/tasks/gemma4-gemm-tuning/tests/test.sh:24`,
`infra-bench/tasks/gemma4-gemm-tuning/tests/test.sh:27`,
`infra-bench/tasks/gemma4-gemm-tuning/tests/test.sh:31`).

Impact: a malicious agent can patch `aiter.tuned_gemm.gemm_a16w16` or its import
surface to slow the "default" path when `AITER_CONFIG_GEMM_BF16=/tmp/no_such_tuned.csv`,
or otherwise make the baseline and tuned measurements incomparable, while still
leaving the trusted CSV shape list intact. This is the same class of mutable
runtime-baseline issue that `paged-attention-hd256` partially addressed with an
AITER source manifest.

Recommendation: snapshot and verify the AITER source used for grading, or run the
baseline from a pristine AITER copy/cache that the agent cannot edit. If AITER JIT
artifacts affect the measured GEMM path, also purge or bind the runtime build
cache before timing.

#### 3. Medium: `llm-fp8-quantize` lacks the pristine-baseline guard used by the SGLang optimization task

`gemma4-sglang-serving-opt` measures its baseline through `/opt/sglang-pristine`
and verifies a build-time hash before running it
(`infra-bench/tasks/gemma4-sglang-serving-opt/environment/Dockerfile:11`,
`infra-bench/tasks/gemma4-sglang-serving-opt/environment/Dockerfile:19`,
`infra-bench/tasks/gemma4-sglang-serving-opt/tests/test.sh:18`,
`infra-bench/tasks/gemma4-sglang-serving-opt/tests/test.sh:22`,
`infra-bench/tasks/gemma4-sglang-serving-opt/tests/bench_lib.sh:33`). In contrast,
`llm-fp8-quantize` measures both the BF16 baseline and the agent FP8 model through
the same mutable post-agent SGLang/eval environment
(`infra-bench/tasks/llm-fp8-quantize/tests/test.sh:32`,
`infra-bench/tasks/llm-fp8-quantize/tests/test.sh:36`,
`infra-bench/tasks/llm-fp8-quantize/tests/bench_lib.sh:37`,
`infra-bench/tasks/llm-fp8-quantize/tests/bench_lib.sh:58`,
`infra-bench/tasks/llm-fp8-quantize/tests/bench_lib.sh:61`). The static FP8 check
only verifies that `/app/fp8_model/config.json` declares an FP8-looking
quantization config (`infra-bench/tasks/llm-fp8-quantize/tests/test.sh:15`,
`infra-bench/tasks/llm-fp8-quantize/tests/test.sh:23`).

Impact: for honest agents, this is a reasonable end-to-end model task. Under the
adversarial shared-container threat model used elsewhere in this review, however,
an agent can patch the shared SGLang server/client/eval stack to slow the BF16
baseline, favor `/app/fp8_model`, or distort parsed throughput/accuracy. The
read-only model mount protects `/models`, but not the code that serves or scores
the models.

Recommendation: either apply the same pristine SGLang/client/eval snapshot pattern
used by `gemma4-sglang-serving-opt`, or document this explicitly as an accepted
shared-mode limitation for this task.

#### 4. Medium: `run_codex.sh` and `run_open_code.sh` report failures but still exit 0

`run_claude_code.sh` pipes `harbor run` through `tee` with `|| true`, then exits
nonzero if no reward files are produced or if any task failed
(`infra-bench/run_claude_code.sh:113`,
`infra-bench/run_claude_code.sh:118`,
`infra-bench/run_claude_code.sh:132`,
`infra-bench/run_claude_code.sh:134`,
`infra-bench/run_claude_code.sh:138`). `run_codex.sh` and `run_open_code.sh` use
the same `harbor run ... | tee ... || true` pattern, summarize `passed/total`, and
then end without the final nonzero-exit guard
(`infra-bench/run_codex.sh:99`,
`infra-bench/run_codex.sh:104`,
`infra-bench/run_codex.sh:116`,
`infra-bench/run_open_code.sh:189`,
`infra-bench/run_open_code.sh:194`,
`infra-bench/run_open_code.sh:209`).

Impact: automation can treat a failed or empty Codex/OpenCode sweep as success.
This is especially risky because the scripts intentionally suppress the raw
`harbor run` exit code so they can print a reward summary.

Recommendation: copy the `total == 0` and `passed != total` exit logic from
`run_claude_code.sh` into both wrappers.

#### 5. Medium: `run_open_code.sh` still exposes the gateway key until post-run scrubbing succeeds

The script documents that `opencode_config` embeds the subscription key and may
land in artifacts (`infra-bench/run_open_code.sh:13`,
`infra-bench/run_open_code.sh:16`). It builds the JSON with
`Ocp-Apim-Subscription-Key` from `AMD_GATEWAY_SUBKEY` and passes the whole config
as a command-line `--ak` value (`infra-bench/run_open_code.sh:63`,
`infra-bench/run_open_code.sh:123`,
`infra-bench/run_open_code.sh:138`,
`infra-bench/run_open_code.sh:141`). The scrub runs only after `harbor run`
returns (`infra-bench/run_open_code.sh:189`,
`infra-bench/run_open_code.sh:196`,
`infra-bench/run_open_code.sh:197`).

Impact: if the script is interrupted, killed, or the machine reboots before line
197, persisted job artifacts can retain the key. The key is also present in the
wrapper process arguments while `harbor run` is executing. This is better than
leaving artifacts permanently unsanitized, but it is not equivalent to the
template-based secret handling in `run_claude_code.sh`/`run_codex.sh`.

Recommendation: prefer a custom OpenCode agent/provider injection path that reads
the key from an environment variable at runtime without serializing it into
`--ak`. As an incremental guard, install an `EXIT` trap after `JOBS_DIR` is known
so `_scrub "$JOBS_DIR"` runs on interruption as well as normal completion.

### Validation Performed In This Pass

Passed:

- `bash -n` over the top-level run/analyze scripts and task shell entrypoints.
- `python3.11 -m py_compile` over tracked InfraBench Python files outside job
  artifacts.
- `python3.11` + `tomllib` parsed task TOML files and confirmed `[task].name`
  matches each task directory.
- `python3.11` + PyYAML parsed GPU-task `environment/docker-compose.yaml` files.

Not run:

- Fresh oracle jobs.
- Fresh GPU, profiler, SGLang, vLLM, or model-serving jobs.
- Adversarial canary submissions.
