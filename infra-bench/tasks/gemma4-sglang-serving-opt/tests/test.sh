#!/bin/bash
# A1 verifier. Runs in the SAME container as the agent (shared mode). Measures a
# BASELINE from the pristine sglang snapshot, then the AGENT's live (edited)
# sglang, both with the fixed canonical launch + benchmark commands, and gates
# on TTFT / throughput / accuracy improvements.
set -u

source /tests/bench_lib.sh

mkdir -p /logs/verifier

# 1) Baseline: pristine sglang via PYTHONPATH override of the editable install.
measure_variant baseline /opt/sglang-pristine /tmp/a1_baseline.json

# 2) Agent: the live (possibly edited) editable tree.
measure_variant agent "" /tmp/a1_agent.json

cp /tmp/a1_baseline.json /tmp/a1_agent.json /logs/verifier/ 2>/dev/null || true

# 3) Gate.
/opt/venv/bin/python -m pip install --quiet --no-input pytest==8.4.1 pytest-json-ctrf==0.3.5
/opt/venv/bin/python -m pytest --ctrf /logs/verifier/ctrf.json /tests/test_outputs.py -rA

if [ $? -eq 0 ]; then
  echo 1 > /logs/verifier/reward.txt
else
  echo 0 > /logs/verifier/reward.txt
fi
