# Codex Round 4 Review: InfraBench 10 Task Packages

Review date: 2026-07-15

Scope: I reviewed the repository after Claude's Round 3 fixes and response. I
checked the changed verifier code for `mem-bandwidth-bench`,
`flydsl-cdna4-preshuffle-gemm`, `engram-triton-kernel`,
`gemma4-sglang-serving-opt`, and `run.sh`, plus the still-deferred shared-mode
surfaces. I did not run fresh GPU jobs in this pass; I inspected the existing
2026-07-15 verifier artifacts Claude left for the changed tasks.

Summary: Claude's Round 3 fixes are present and several previous issues are
closed or improved: `mem-bandwidth-bench` now uses one `FETCH_SIZE` run for both
timing and traffic, FlyDSL keeps the dump env enabled across its candidate timing
loop, SGLang/Engram manifests are fail-hard and broader, and `run.sh` now parses
`-p`/`--path` token-by-token. The remaining issues are mainly verifier
trust-boundary problems that still matter if agents are considered adversarial,
even in SHARED mode.

## Current Findings

### 1. High: `mem-bandwidth-bench` still trusts profiler CSV files written in an agent-writable directory

The same-run fix is a real improvement: the grader now runs only
`rocprofv3 --pmc FETCH_SIZE ... -- bash /app/measure_bandwidth.sh` and reads both
duration and `FETCH_SIZE` from `*counter_collection.csv`
(`infra-bench/tasks/mem-bandwidth-bench/tests/grade_bandwidth.py:63`,
`infra-bench/tasks/mem-bandwidth-bench/tests/grade_bandwidth.py:111`). This
removes the previous two-execution timing/traffic mismatch.

However, the profiler output directory is fixed at `/tmp/bw_prof` and the
untrusted benchmark script runs inside the same container and privilege boundary
(`infra-bench/tasks/mem-bandwidth-bench/tests/grade_bandwidth.py:109`,
`infra-bench/tasks/mem-bandwidth-bench/tests/grade_bandwidth.py:112`). The parser
then blindly globs every `*counter_collection.csv` under that directory and
trusts rows with `Counter_Name == FETCH_SIZE`
(`infra-bench/tasks/mem-bandwidth-bench/tests/grade_bandwidth.py:73`,
`infra-bench/tasks/mem-bandwidth-bench/tests/grade_bandwidth.py:76`). An
adversarial `/app/measure_bandwidth.sh` can create an additional fake
`counter_collection.csv` with many rows for a made-up kernel name, chosen
Start/End timestamps, and chosen `FETCH_SIZE` values. Because the grader selects
the most-dispatched non-helper kernel (`infra-bench/tasks/mem-bandwidth-bench/tests/grade_bandwidth.py:153`),
the fake rows can dominate the real profiler output.

Impact: the verifier no longer has the cross-run hole, but it still does not
prove that the CSV came from rocprof rather than from the agent's script. The
task documentation currently says "same-run fabrication-proof"
(`docs/infra_bench_task.md:16`), which is still too strong under adversarial
SHARED mode.

Recommendation: do not let the measured program write into the profiler artifact
directory, or do not parse profiler artifacts from a filesystem the measured
program can modify. Practically, this means a separate verifier user/container or
a verifier-owned harness that runs only trusted code around the agent kernel. If
staying in SHARED/root mode, at least make this limitation explicit and consider
cross-checking rocprof metadata/PIDs, but that will still be weaker than an
unshared artifact boundary.

### 2. High: FlyDSL performance can be faked because timed-loop outputs are never checked

Round 3 fixed the previous ISA-window issue by keeping `FLYDSL_DUMP_IR` enabled
while `_bench_kernel` times the candidate (`infra-bench/tasks/flydsl-cdna4-preshuffle-gemm/tests/bench_preshuffle_gemm.py:109`,
`infra-bench/tasks/flydsl-cdna4-preshuffle-gemm/tests/bench_preshuffle_gemm.py:112`,
`infra-bench/tasks/flydsl-cdna4-preshuffle-gemm/tests/bench_preshuffle_gemm.py:113`).
That is better, but the benchmark still checks candidate correctness on only one
call:

- `candidate_C = _run_kernel(...)` is the only candidate output compared against
  expected values (`infra-bench/tasks/flydsl-cdna4-preshuffle-gemm/tests/bench_preshuffle_gemm.py:112`,
  `infra-bench/tasks/flydsl-cdna4-preshuffle-gemm/tests/bench_preshuffle_gemm.py:124`,
  `infra-bench/tasks/flydsl-cdna4-preshuffle-gemm/tests/bench_preshuffle_gemm.py:127`).
- `_bench_kernel` allocates a fresh `C`, records events, calls
  `module.preshuffle_gemm`, and returns only times; it never validates any timed
  output (`infra-bench/tasks/flydsl-cdna4-preshuffle-gemm/tests/bench_preshuffle_gemm.py:38`,
  `infra-bench/tasks/flydsl-cdna4-preshuffle-gemm/tests/bench_preshuffle_gemm.py:44`,
  `infra-bench/tasks/flydsl-cdna4-preshuffle-gemm/tests/bench_preshuffle_gemm.py:50`,
  `infra-bench/tasks/flydsl-cdna4-preshuffle-gemm/tests/bench_preshuffle_gemm.py:54`).
- The grader gates speed using `candidate["perf"]["median_ms"]` while accuracy
  still comes from the separate earlier candidate output
  (`infra-bench/tasks/flydsl-cdna4-preshuffle-gemm/tests/grade_preshuffle_gemm.py:187`,
  `infra-bench/tasks/flydsl-cdna4-preshuffle-gemm/tests/grade_preshuffle_gemm.py:189`,
  `infra-bench/tasks/flydsl-cdna4-preshuffle-gemm/tests/grade_preshuffle_gemm.py:217`).

Impact: a stateful candidate can compute correctly on the first call, emit a
valid CDNA4 ISA dump, and then make every warmup/timed repeat a no-op or route it
through some other path. The verifier would see correct `candidate_C`, a fast
median time, and a CDNA4 `.s` file, even though the timed path did not compute
the GEMM.

Recommendation: make `_bench_kernel` validate timed outputs. For example, return
and check the final timed `C`, or randomly validate one warmup/timed iteration.
For stronger coverage, time a wrapper that both launches the kernel and checks a
small deterministic checksum after synchronization, or run correctness again
after the timing loop to catch call-count based behavior.

### 3. High if adversarial agents are in scope: serving/profiling metric clients remain mutable by design

Claude explicitly deferred this under the SHARED-mode decision. That is a valid
product decision if InfraBench only targets non-malicious agents, but it remains a
large not-hackable gap.

In `gemma4-sglang-serving-opt`, the baseline server import path is guarded, but
the throughput and accuracy clients still run from mutable post-agent code:
`python3 -m sglang.bench_serving` and `sgl-eval` are invoked without a trusted
client environment (`infra-bench/tasks/gemma4-sglang-serving-opt/tests/bench_lib.sh:12`,
`infra-bench/tasks/gemma4-sglang-serving-opt/tests/bench_lib.sh:18`,
`infra-bench/tasks/gemma4-sglang-serving-opt/tests/bench_lib.sh:77`,
`infra-bench/tasks/gemma4-sglang-serving-opt/tests/bench_lib.sh:80`). The same
pattern exists in `llm-fp8-quantize`
(`infra-bench/tasks/llm-fp8-quantize/tests/bench_lib.sh:11`,
`infra-bench/tasks/llm-fp8-quantize/tests/bench_lib.sh:15`,
`infra-bench/tasks/llm-fp8-quantize/tests/bench_lib.sh:58`,
`infra-bench/tasks/llm-fp8-quantize/tests/bench_lib.sh:61`). The hotspot task
also profiles the live mutable SGLang stack after the agent phase
(`infra-bench/tasks/hotspot-analysis-torch-profiler/tests/test.sh:11`,
`infra-bench/tasks/hotspot-analysis-torch-profiler/tests/profile_workload.py:35`,
`infra-bench/tasks/hotspot-analysis-torch-profiler/tests/profile_workload.py:46`).

Impact: a malicious agent can alter benchmark/eval clients or shared serving
dependencies to fabricate TTFT, throughput, GSM8K, or hotspot metrics without
performing the requested optimization.

Recommendation: if adversarial robustness is required, run metric clients from a
trusted verifier environment or use verifier-owned minimal HTTP clients under a
separate trust boundary. If SHARED mode is intentionally accepted, document that
these serving tasks are not hardened against metric-client tampering.

### 4. Medium: PointNet++ kernel tracing can still be satisfied by fallback code plus fake or dummy traces

The PointNet++ verifier still has the Round 3 accepted limitation: it checks
numerics through the public Python wrappers and separately checks for kernel-name
substrings in profiler output (`infra-bench/tasks/pointnet2-hipify/tests/check_numerics.py:67`,
`infra-bench/tasks/pointnet2-hipify/tests/check_numerics.py:100`,
`infra-bench/tasks/pointnet2-hipify/tests/check_numerics.py:107`,
`infra-bench/tasks/pointnet2-hipify/tests/check_numerics.py:110`). This does not
prove that those named kernels produced the numerically checked tensors.

The same artifact-trust issue applies here too: the trace directory is fixed at
`/tmp/pn2_prof`, and the agent-controlled package code executes while the trace
is being collected (`infra-bench/tasks/pointnet2-hipify/tests/check_numerics.py:70`,
`infra-bench/tasks/pointnet2-hipify/tests/check_numerics.py:101`). A fallback
implementation can compute numerics with Torch and create or trigger trace rows
with the expected names.

Recommendation: call native `_ext` functions directly for each op/grad path and
validate their outputs. If profiler evidence remains required, protect the trace
directory or correlate launches with direct native calls; otherwise treat the
trace check as a heuristic, not proof.

### 5. Medium: GPU isolation still relies on `BASH_ENV`, not device-level isolation

All GPU task compose files still pass through `/dev/kfd` and `/dev/dri` and rely
on `BASH_ENV` to set `HIP_VISIBLE_DEVICES`/`CUDA_VISIBLE_DEVICES`
(`infra-bench/tasks/hello-rocm/environment/docker-compose.yaml:5`,
`infra-bench/tasks/hello-rocm/environment/pin_gpu.sh:3`). The hello verifier
explicitly notes that direct Python can see the full pool because pinning only
applies to bash execs (`infra-bench/tasks/hello-rocm/tests/test_outputs.py:38`).

Impact: non-bash commands or explicit environment changes can bypass the claimed
GPU, so concurrent performance tasks can still contaminate each other.

Recommendation: enforce the selected GPU below shell startup, either in docker
exec/container environment handling or through device/cgroup restrictions.

## Fixed Or Improved Since Round 3

- `mem-bandwidth-bench` now uses one `rocprofv3 --pmc FETCH_SIZE` execution for
  both timing and HBM-traffic evidence. The previous cross-run spoof is closed.
- `flydsl-cdna4-preshuffle-gemm` now keeps `FLYDSL_DUMP_IR` enabled across the
  candidate timing loop. The old "dumped probe call only" issue is improved, but
  timed outputs still need validation.
- `gemma4-sglang-serving-opt` and `engram-triton-kernel` now fail hard when their
  manifests are missing and hash all non-bytecode reference files, not only
  `*.py`.
- `run.sh` now detects `-p`, `--path`, and `--path=...` by scanning `"$@"`
  token-by-token, so substring values no longer accidentally disable all-task
  mode.
- The latest visible verifier artifacts show successful 2026-07-15 oracle runs
  for the changed tasks:
  `infra-bench/jobs/2026-07-15__01-00-48/mem-bandwidth-bench__m2mjW4q`,
  `infra-bench/jobs/2026-07-15__01-16-22/flydsl-cdna4-preshuffle-gemm__2obYqJT`,
  `infra-bench/jobs/2026-07-15__01-27-44/engram-triton-kernel__qaM6KTd`, and
  `infra-bench/jobs/2026-07-15__01-39-20/gemma4-sglang-serving-opt__dbTL5yJ`.

## Still Deferred / Accepted By Current Threat Model

- Full verifier isolation through SEPARATE/fresh trusted containers.
- Serving metric-client integrity.
- PointNet++ output provenance beyond kernel-name trace presence.
- GPU isolation below `BASH_ENV`.
- Hidden workload variants across serving, Engram, FlyDSL, GEMM tuning, and
  PointNet++.
- Dependency pinning and offline reproducibility. All tasks still have
  `allow_internet = true`, and most verifier scripts install pytest at grade time.
- Public/private release packaging. `solution/` directories and hidden-looking
  reference directories remain in the repository.

## Validation Performed In This Pass

Passed:

- `bash -n infra-bench/run.sh infra-bench/analyze.sh infra-bench/tasks/*/tests/test.sh infra-bench/tasks/*/solution/solve.sh infra-bench/tasks/*/environment/claim_gpu.sh infra-bench/tasks/*/environment/pin_gpu.sh`
- `python3.11 -m py_compile $(rg --files infra-bench/tasks -g '*.py')`
- `python3.11` + `tomllib` parsed all ten `task.toml` files and confirmed task
  names match `infra-bench/<directory-name>`.
- `python3.11` + PyYAML parsed all GPU-task `environment/docker-compose.yaml`
  files.

Not run in this pass:

- Fresh Harbor jobs, fresh GPU profiler jobs, or adversarial canary submissions.
  The findings above are source-level verifier review findings.

## Suggested Priority

1. Fix FlyDSL timed-output validation; this is the most direct remaining
   task-local bypass.
2. Decide whether profiler artifacts produced in agent-writable directories are
   acceptable under the SHARED-mode threat model. If not, move those checks behind
   a real verifier trust boundary.
3. Document the accepted SHARED-mode limitations explicitly in task/docs language,
   especially for serving metrics and "fabrication-proof" claims.
4. Keep the Round 3 fixes; they are directionally correct and should not be
   reverted.
