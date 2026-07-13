You are analyzing GPU performance of an LLM inference workload on an AMD MI350
GPU. Your job is to profile a specific serving workload and identify the single
most time-consuming GPU kernel.

## The workload to analyze

An sglang server for `google/gemma-4-26B-A4B-it` serving requests of:
- **8192 input tokens**, **5 output tokens**, **concurrency 1**

Launch the server with exactly this command (the same one the grader uses):

```
python -m sglang.launch_server --model /models/gemma-4-26B-A4B-it \
  --disable-radix-cache --host 0.0.0.0 --port 30000
```

Drive the fixed workload with exactly this benchmark, which also toggles the
profiler around the run (the same one the grader uses):

```
python3 -m sglang.bench_serving --backend sglang --dataset-name random --profile \
  --num-prompt 4 --max-concurrency 1 --port 30000 \
  --random-input-len 8192 --random-output-len 5 --random-range-ratio 1.0
```

(`--profile` requires `SGLANG_TORCH_PROFILER_DIR` to be set to a directory; the
trace is written under it. Profiling 4 requests rather than one makes the
per-kernel time share stable.)

## What to produce

Profile the GPU kernels executed during that request and determine which single
kernel consumes the largest share of total GPU kernel time. Write your finding
to `/app/hotspot.json` with exactly these fields:

```json
{
  "kernel": "<exact kernel name as it appears in the profiler trace>",
  "pct": <percentage of total GPU kernel time>
}
```

- `kernel`: the exact kernel name string from the trace (not a paraphrase).
- `pct`: that kernel's total GPU time as a percentage of the sum of all GPU
  kernel times, in [0, 100].

## Hints

- sglang has a built-in profiler: `POST /start_profile` (you can request GPU
  activities and an output directory) and `POST /stop_profile`. It writes a
  Chrome/torch trace file. Investigate its output format to aggregate per-kernel
  GPU time.
- The GPU assigned to this container is pre-selected; use the default device.
- Your answer must reflect the REAL profile of this workload — the grader
  re-profiles the same workload and compares against its own measurement.
