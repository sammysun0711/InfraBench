#!/bin/bash
# F3 verifier (benchmark-only, no re-tune). Times the DEFAULT kernel selection
# and the agent's tuned config over the same shapes with aiter's production op,
# then gates on aggregate speedup + per-shape correctness.
set -u

mkdir -p /logs/verifier
UNTUNED=/app/gemma4_untuned_gemm.csv
AGENT=/app/gemma4_tuned_gemm.csv

if [ ! -f "$AGENT" ]; then
  echo "[verifier] agent tuned config $AGENT not found"
  echo 0 > /logs/verifier/reward.txt; exit 0
fi

# 1) Baseline: default kernels over the untuned shape list.
/opt/venv/bin/python /tests/bench_gemm.py --mode baseline --path "$UNTUNED" --out /tmp/baseline.json

# 2) Agent: the tuned config.
/opt/venv/bin/python /tests/bench_gemm.py --mode config --path "$AGENT" --out /tmp/agent.json

cp /tmp/baseline.json /tmp/agent.json /logs/verifier/ 2>/dev/null || true

# 3) Gate.
/opt/venv/bin/python -m pip install --quiet --no-input pytest==8.4.1 pytest-json-ctrf==0.3.5
/opt/venv/bin/python -m pytest --ctrf /logs/verifier/ctrf.json /tests/test_outputs.py -rA

if [ $? -eq 0 ]; then
  echo 1 > /logs/verifier/reward.txt
else
  echo 0 > /logs/verifier/reward.txt
fi
