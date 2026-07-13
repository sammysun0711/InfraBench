# InfraBench Development Plan

Benchmark of 20 AI-Infra engineering tasks on AMD MI350 GPUs, run through the
`harbor` harness (Terminal-Bench style), plus a per-task model-routing analysis.
This document is the working plan; update it as decisions change.

## Goal & standard

Each task must meet the Terminal-Bench-2-1 bar:

- **Specified** — instruction.md gives a precise contract: exact file paths,
  required entrypoints/signatures, and explicit, measurable success criteria.
- **Verifiable** — a deterministic `tests/test.sh` writes `1`/`0` to
  `/logs/verifier/reward.txt`; pytest assertions emit `ctrf.json`.
- **Solvable** — a `solution/solve.sh` scores reward **1.0** under the `oracle`
  agent. No task ships until oracle passes.
- **Not hackable** — the agent cannot pass by reading the solution, editing the
  tests, or writing `reward.txt` directly. Reference material that must stay
  hidden goes in `environment/protected.tar.gz.enc` (decrypted only by
  `solve.sh`), and verifiers assert on real behavior, not just file presence.

## Confirmed environment facts

- **Host**: 8× MI350 (288 GB HBM each). Devices: `/dev/kfd`, `/dev/dri`.
  Host GIDs — `video=44`, `render=109`. `rocm-smi`/`rocminfo` present on host.
- **Canonical AMD dev-container run command (reference):**
  ```
  docker run -it --privileged --cap-add=SYS_PTRACE \
    --security-opt seccomp=unconfined --network=host \
    --device /dev/kfd --device /dev/dri --group-add render \
    --ipc=host --entrypoint /bin/bash <image>
  ```
- **GPU passthrough verified — all 8 GPUs visible.** Preferred recipe is the
  minimal, non-privileged one below; the reference `--privileged` command also
  works but grants far more host access than needed.
  - **Preferred:** device mounts + `--group-add video` (NO `--privileged`).
    Verified on BOTH base images:
    ```
    docker run --rm --device /dev/kfd --device /dev/dri \
      --group-add video --security-opt seccomp=unconfined --ipc=host \
      --cap-add=SYS_PTRACE <image> rocminfo
    ```
  - **Group-name portability:** `video` (gid 44) exists in BOTH images →
    `--group-add video` works by name everywhere. `render` exists only in the
    sglang image (gid 110), NOT in rocm/pytorch → `--group-add render` errors
    there. So standardize on `video`.
  - `--cap-add=SYS_PTRACE` + `seccomp=unconfined`: keep for profiling / debug-
    triage tasks (rocprof, gdb). Harmless for others.
  - `--ipc=host`: matters for multi-process / large-shm workloads (sglang, RCCL).
- **Compose translation** (for `environment/docker-compose.yaml`):
  ```yaml
  services:
    main:
      image: <base image>
      cap_add: [SYS_PTRACE]
      security_opt: ["seccomp=unconfined"]
      ipc: host
      group_add: ["video"]
      devices: ["/dev/kfd", "/dev/dri"]
      # network_mode: host  # only if a task needs it; harbor manages networking
  ```
- **harbor does NOT wire GPUs into the local Docker env automatically.** The
  `gpus` field in `task.toml` is metadata only; `write_resources_compose_file`
  handles cpu/memory only. GPU access must come from the task's compose file.
- **Two ways to inject device config:**
  1. Ship `environment/docker-compose.yaml` in the task package (harbor accepts
     compose *or* Dockerfile). Self-contained → portable dataset. **Preferred.**
  2. Run-time `--extra-docker-compose <file>` overlay. Good for a spike, but not
     baked into the task.
- **Base images (already pulled locally):**
  - General GPU / kernel / profiling:
    `rocm/pytorch:rocm7.2.4_ubuntu24.04_py3.12_pytorch_release_2.10.0`
  - AI-framework / serving tasks:
    `lmsysorg/sglang:v0.5.15-rocm720-mi35x`
- **Gateway auth is solved** — see `terminal-bench/run.sh` / `analyze.sh`
  (`--ae ANTHROPIC_CUSTOM_HEADERS=...`). Valid model ids on the AMD gateway:
  `claude-opus-4.8`, `claude-haiku-4-5` (NOT `claude-haiku-4.8`).

## Directory layout

```
InfraBench/
  terminal-bench/          # existing harbor working dir (run.sh, analyze.sh, jobs/)
  infra-bench/             # NEW — our dataset + scripts
    tasks/
      hello-rocm/          # Phase 0 spike
      <task>/ ...          # 20 tasks
    dataset.toml           # harbor dataset manifest listing the tasks
    run.sh                 # gateway-aware wrapper (ported from terminal-bench)
    analyze.sh             # gateway-aware wrapper (ported)
    jobs/                  # eval outputs (immutable artifacts)
  infra-bench-develop-plan.md
```

`run.sh`/`analyze.sh` carry over the `--ae` gateway header pattern. Concurrency
default `-n 4` (8 GPUs available; leaves headroom during experiments).

## Task package anatomy (per task)

```
tasks/<name>/
  task.toml                    # metadata, resources, timeouts, gpus=1
  instruction.md               # the NL task (the contract)
  environment/
    docker-compose.yaml        # base image + GPU device passthrough
    Dockerfile                 # (if extra setup on top of base image)
    protected.tar.gz.enc       # hidden reference material (optional)
  tests/
    test.sh                    # verifier entrypoint → reward.txt
    test_outputs.py            # deterministic pytest assertions → ctrf.json
  solution/
    solve.sh                   # oracle solution; must score 1.0
```

## Phased execution

### Phase 0 — `hello-rocm` GPU harness spike ✅ DONE
De-risked the whole benchmark. Task at `infra-bench/tasks/hello-rocm/`.

- Task: agent reads GPU info via PyTorch and writes `/app/gpu_report.json`
  (visible_device_count, device_name, gcn_arch). Verifier measures ground truth
  itself and compares → not hackable. MI350 reports arch `gfx950`.
- **Results (both via `infra-bench/run.sh`, gateway auth working):**
  - `oracle` → reward 1.0 (task/verifier/GPU wiring sound).
  - `claude-code` @ claude-opus-4.8 → reward 1.0 (full agent loop works on GPU,
    `apiKeySource: ANTHROPIC_API_KEY`, real model turns).
- **Proven building blocks now reusable for all tasks:**
  - Package layout: Dockerfile (from `rocm/pytorch`) + `docker-compose.yaml`
    override on `main` (device passthrough, `group_add: [video]`, no privileged).
  - GPU-pool allocator: `claim_gpu.sh` (flock held for container lifetime → auto
    reuse, no stale locks) + `pin_gpu.sh` sourced via `BASH_ENV` (auto-sets
    `HIP_VISIBLE_DEVICES` in every exec). Pool dir bind-mounted from host via
    `${INFRABENCH_GPU_POOL_HOST}`, exported by `run.sh`.
  - **`task.toml` must set `gpus = 0`** — harbor's Docker env only recognizes
    nvidia-docker and rejects `gpus>0`; real GPU access comes from the compose
    file, not harbor's allocator.
  - Verifier uses image's `/opt/venv/bin/python` (has torch) + pip-installed
    pytest, NOT an isolated uvx env.
  - Count assertion is `>=1` not `==N` (auto-pin masks to 1 only for bash execs;
    name/arch are invocation-independent and checked strictly).
  - **Model mount**: host `/data/models` bind-mounted read-only into every
    trial via the task compose `volumes:` (`${INFRABENCH_MODELS_HOST:-/data/models}:/models:ro`),
    exported by `run.sh`. Models: `/models/gpt-oss-20b` (full, MoE/mxfp4; serving
    verified on `lmsysorg/sglang:v0.5.15-rocm720-mi35x`),
    `/models/Qwen3.5-0.8B` (cheap verifier). Pure-kernel tasks skip this and use
    synthetic tensors. RO mount verified; agents reuse weights, no re-download.

### Phase 1 — Template + 1 task per category (vertical slices)
Lock the InfraBench task template, then author ONE task in each of the 5
categories and get each oracle-verified. Validates category definitions before
scaling. Categories:
1. Model deployment
2. Profiling analysis
3. Kernel implementation
4. Kernel tuning
5. Debug triage

(Concrete task ideas per category: TBD — brainstorm list below.)

### Phase 2 — Scale to 20 tasks
4 tasks per category. Each: specified, verifiable, oracle-passes, hack-resistant.
Add each to `dataset.toml`. Spot-check a few with `claude-code` to gauge
difficulty (should not be trivially solved, should be solvable by a strong agent).

### Phase 3 — Multi-agent + routing
- Wire `codex` and `opencode` (open-source models) through the gateway, same
  `--ae` header pattern as claude-code (verify each agent's env plumbing).
- Run all agents × 20 tasks (with `-k` repeats for success-rate stability).
- Build the routing analysis: weighted efficiency (success rate, latency) vs.
  inverse cost; Pareto-frontier heuristic recommending the cheapest model above
  an efficiency threshold.

## Candidate task list (BRAINSTORM — to be vetted against the standard)

Vet each for: specified / verifiable / solvable / not-hackable. Fill in.

| # | Category | Candidate task | Verifiable signal | Notes |
|---|----------|----------------|-------------------|-------|
| 1 | Deployment | e.g. serve a model on sglang, meet a latency/throughput target | benchmark script asserts p50/throughput | base: sglang image |
| 2 | Profiling | e.g. profile a kernel, extract top hotspot from rocprof trace | assert reported hotspot / metric | |
| 3 | Kernel impl | e.g. implement a fused HIP/Triton kernel, match reference output | numerical allclose vs. reference | |
| 4 | Kernel tuning | e.g. tune block/tile config to beat a perf baseline | assert speedup ≥ threshold vs. baseline | |
| 5 | Debug triage | e.g. root-cause a failing RCCL/OOM job, apply fix | job runs green after fix | |

## Open questions / risks

- **GPU exclusivity under `-n 4` → lockfile GPU pool (decided approach).**
  Perf-sensitive tasks (tuning, latency) get noisy measurements if trials share
  a GPU. We want each concurrent trial pinned to a distinct GPU, and a freed GPU
  reused by the next trial (GPU pool of size = total GPUs; ≤ `-n` held at once).
  - Harbor concurrency is an asyncio **semaphore** (`trial/queue.py`) with NO
    stable per-trial slot index, so we cannot statically map slot→GPU. Use a
    dynamic **claim/release allocator** instead.
  - All GPUs are always device-mounted (`/dev/dri` exposes every card);
    `HIP_VISIBLE_DEVICES` is the real restriction lever — mask, don't unmount.
  - Mechanism: mount a shared host pool dir into every container (via
    `environment.env` `${VAR}` interpolation). At task start, `claim_gpu.sh`
    uses `flock` over `pool/gpuN.lock`, grabs the first free index N, persists
    it, and exports `HIP_VISIBLE_DEVICES=N`. On exit (trap) the lock releases.
    Multi-GPU tasks claim a pair.
  - **Phase-0 validation results (RESOLVED):**
    - (a) **Verifier shares the agent's container.** Harbor's verifier mode
      defaults to **SHARED** (`verifier_mode.py:26`) — agent and verifier are
      separate `docker exec`s into the SAME long-lived `main` container, so they
      share the filesystem. It only becomes SEPARATE if a task declares
      `verifier.environment`. **Keep tasks SHARED** so the claim survives.
    - (b) **Mounted pool dir is writable.** Container runs as root (0:0); a
      host bind-mount is fully read/write from inside, files appear on the host
      immediately, and `flock` works over the mount.
    - (c) **Env vars do NOT persist across execs** (new finding). Each harbor
      phase is a fresh `docker exec`, so `export HIP_VISIBLE_DEVICES=N` (or even
      writing `/etc/environment`) in the claim step is EMPTY in later execs —
      login shells didn't pick it up either. A **file** written to the pool /
      container IS readable by every later exec.
- **GPU claim design (finalized, file-carrier not env-carrier):**
  - Carry the chosen index in a FILE, not an exported env var.
  - `claim_gpu.sh` (run at task start): `flock` the pool, pick first free index
    N, write it to `/pool/<trial>.gpu` and a container-local `/tmp/claimed_gpu`.
  - Every command needing the GPU sources it:
    `export HIP_VISIBLE_DEVICES=$(cat /tmp/claimed_gpu)`. We control `test.sh`,
    `solve.sh`, and the task scripts, so this is easy; the instruction tells the
    agent to use the assigned GPU (or a sourced shell profile pins it).
  - Release on trial end (trap / harbor teardown removes the container, which
    drops the container-local file; pool lock cleared by a release step).
- **Perf-threshold verifiers must have margin** so they aren't flaky across runs.
- **Non-hackability for perf tasks:** ensure the agent can't hardcode/fake the
  benchmark output; verifier should run its own measurement.
```
