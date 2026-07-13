#!/usr/bin/env bash
# Shared helpers for the A1 verifier: launch an sglang server (baseline or
# agent), wait for real health, benchmark throughput + accuracy, emit metrics.
#
# measure_variant <label> <pythonpath-or-empty> <out-json>
#   - launches the canonical server command (optionally with PYTHONPATH override
#     for the pristine baseline), waits for /health_generate,
#   - runs the fixed bench_serving + sgl-eval,
#   - writes {ttft_ms, total_throughput, output_throughput, gsm8k} to <out-json>.

LAUNCH_CMD='python -m sglang.launch_server --model /models/gemma-4-26B-A4B-it --disable-radix-cache --host 0.0.0.0 --port 30000'
BENCH_CMD='python3 -m sglang.bench_serving --backend sglang --dataset-name random --num-prompt 128 --max-concurrency 8 --port 30000 --random-input-len 8192 --random-output-len 1024 --random-range-ratio 1.0'
# --max-tokens caps generation: gsm8k answers need only a few hundred tokens,
# but with the default (None -> server cap ~131K) a single degenerate
# non-stopping generation can run for 30+ min and stall the whole eval. Capping
# at 2048 kills that straggler with zero effect on correctness (a right answer
# never needs more), making the verifier fast AND deterministic.
GSM8K_CMD='sgl-eval run gsm8k --base-url http://localhost:30000/v1 --num-examples 200 --max-tokens 2048'

_kill_server() {
  pkill -9 -f sglang 2>/dev/null
  pkill -9 -f launch_server 2>/dev/null
  sleep 5
}

measure_variant() {
  local label="$1" pypath="$2" out="$3"
  local log="/tmp/a1_${label}_server.log"
  local bench="/tmp/a1_${label}_bench.txt"
  local gsm="/tmp/a1_${label}_gsm8k.txt"

  _kill_server
  # Guard: a baseline variant MUST resolve sglang to the pristine snapshot.
  # If the snapshot dir is missing/misplaced, PYTHONPATH silently falls back to
  # the editable (agent-edited) tree and the baseline would measure the wrong
  # code. Fail loudly instead.
  if [ -n "$pypath" ]; then
    if [ ! -f "$pypath/sglang/__init__.py" ]; then
      echo "[verifier] FATAL: pristine snapshot not found at $pypath/sglang"
      echo '{"error":"pristine_snapshot_missing"}' > "$out"
      return 1
    fi
    local _resolved
    _resolved=$(PYTHONPATH="$pypath" python3 -c "import sglang,os;print(os.path.dirname(sglang.__file__))" 2>/dev/null)
    if [ "$_resolved" != "$pypath/sglang" ]; then
      echo "[verifier] FATAL: baseline sglang resolved to '$_resolved', not '$pypath/sglang'"
      echo '{"error":"pristine_resolution_failed"}' > "$out"
      return 1
    fi
    echo "[verifier] baseline sglang confirmed at $_resolved"
  fi
  echo "[verifier] launching $label server (PYTHONPATH='${pypath}')"
  if [ -n "$pypath" ]; then
    PYTHONPATH="$pypath" bash -c "$LAUNCH_CMD" > "$log" 2>&1 &
  else
    bash -c "$LAUNCH_CMD" > "$log" 2>&1 &
  fi

  # Wait up to ~12 min for real health (long weight load + warmup).
  local ok=0 i
  for i in $(seq 1 144); do
    if curl -s -m 5 http://0.0.0.0:30000/health_generate >/dev/null 2>&1; then ok=1; break; fi
    if grep -qE "address already in use|Fatal Python error|CUDA error|HIP error|Traceback|RuntimeError" "$log" 2>/dev/null; then
      echo "[verifier] $label launch failed:"; grep -iE "error|Traceback" "$log" | grep -viE "Deprecat|does not support intermediate|Ignore import" | tail -4
      break
    fi
    sleep 5
  done
  if [ "$ok" != 1 ]; then
    echo "[verifier] $label NOT healthy; aborting variant"
    echo '{"error":"server_not_healthy"}' > "$out"
    _kill_server
    return 1
  fi

  echo "[verifier] $label: running throughput benchmark"
  HF_HUB_OFFLINE=0 bash -c "$BENCH_CMD" > "$bench" 2>&1

  echo "[verifier] $label: running gsm8k accuracy"
  bash -c "$GSM8K_CMD" > "$gsm" 2>&1

  _kill_server

  # Extract metrics with python (robust parsing).
  python3 - "$bench" "$gsm" "$out" <<'PY'
import re, json, sys
bench, gsm, out = sys.argv[1], sys.argv[2], sys.argv[3]
btxt = open(bench, errors="ignore").read()
gtxt = open(gsm, errors="ignore").read()

def grab(pat, txt, cast=float):
    m = re.search(pat, txt)
    return cast(m.group(1)) if m else None

metrics = {
    "ttft_ms":            grab(r"Mean TTFT \(ms\):\s*([\d.]+)", btxt),
    "total_throughput":   grab(r"Total token throughput \(tok/s\):\s*([\d.]+)", btxt),
    "output_throughput":  grab(r"Output token throughput \(tok/s\):\s*([\d.]+)", btxt),
    # sgl-eval prints e.g. "* score           =  98.50%"
    "gsm8k":              grab(r"score\s*=\s*([\d.]+)%", gtxt),
}
if metrics["gsm8k"] is not None:
    metrics["gsm8k"] /= 100.0
json.dump(metrics, open(out, "w"), indent=2)
print(f"[verifier] {out}: {metrics}")
PY
}
