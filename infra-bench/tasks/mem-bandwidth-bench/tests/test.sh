#!/bin/bash
# mem-bandwidth verifier: run the agent's benchmark under rocprofv3, then gate on
# (A) reported bandwidth in a plausible band + (C) real GPU kernels dispatched.
set -u

mkdir -p /logs/verifier

if [ ! -f /app/measure_bandwidth.sh ]; then
  echo "[verifier] /app/measure_bandwidth.sh not found"
  echo 0 > /logs/verifier/reward.txt; exit 0
fi

python /tests/grade_bandwidth.py > /tmp/grade_stdout.txt 2>&1 || true
cat /tmp/grade_stdout.txt | tail -20
cp /tmp/bw_grade.json /tmp/grade_stdout.txt /tmp/bw_run.log /logs/verifier/ 2>/dev/null || true

python -m pip install --quiet --no-input pytest==8.4.1 pytest-json-ctrf==0.3.5
python -m pytest --ctrf /logs/verifier/ctrf.json /tests/test_outputs.py -rA

if [ $? -eq 0 ]; then
  echo 1 > /logs/verifier/reward.txt
else
  echo 0 > /logs/verifier/reward.txt
fi
