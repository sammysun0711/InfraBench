#!/bin/bash
# F3 verifier (benchmark-only, no re-tune). Times the DEFAULT kernel selection
# and the agent's tuned config over the same shapes with aiter's production op,
# then gates on aggregate speedup + per-shape correctness.
set -u

mkdir -p /logs/verifier
# Trusted shape list ships with the verifier in /tests (uploaded only at grade
# time), NOT the agent-writable /app copy — so an agent cannot shrink or alter
# the benchmark workload before grading. /app still has its copy for reference.
UNTUNED=/tests/gemma4_untuned_gemm.csv
AGENT=/app/gemma4_tuned_gemm.csv

if [ ! -f "$UNTUNED" ]; then
  echo "[verifier] trusted shape list $UNTUNED not found"
  echo 0 > /logs/verifier/reward.txt; exit 0
fi
if [ ! -f "$AGENT" ]; then
  echo "[verifier] agent tuned config $AGENT not found"
  echo 0 > /logs/verifier/reward.txt; exit 0
fi

# Both runs benchmark the SAME full shape list (the trusted /tests copy);
# baseline vs tuned is selected purely by AITER_CONFIG_GEMM_BF16.

# 1) Baseline: point config at a nonexistent file → production op uses defaults.
AITER_CONFIG_GEMM_BF16=/tmp/no_such_tuned.csv \
  /opt/venv/bin/python /tests/bench_gemm.py --input "$UNTUNED" --out /tmp/baseline.json

# 2) Agent: point config at the agent's tuned CSV (tuned where present, else default).
AITER_CONFIG_GEMM_BF16="$AGENT" \
  /opt/venv/bin/python /tests/bench_gemm.py --input "$UNTUNED" --out /tmp/agent.json

cp /tmp/baseline.json /tmp/agent.json /logs/verifier/ 2>/dev/null || true

# 3) Gate.
/opt/venv/bin/python -m pip install --quiet --no-input pytest==8.4.1 pytest-json-ctrf==0.3.5
/opt/venv/bin/python -m pytest --ctrf /logs/verifier/ctrf.json /tests/test_outputs.py -rA

if [ $? -eq 0 ]; then
  echo 1 > /logs/verifier/reward.txt
else
  echo 0 > /logs/verifier/reward.txt
fi
