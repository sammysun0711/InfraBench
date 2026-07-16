#!/bin/bash
# qr-rmsnorm-fusion verifier. Runs in the SAME container as the agent (shared
# mode) so the agent's kernel edit is in place. Rebuilds the agent's aiter kernel
# (AITER_REBUILD=1), runs the 2-GPU accuracy test, and profiles fused-vs-unfused
# under rocprofv3 kernel-trace for the perf gate.
set -u

mkdir -p /logs/verifier

python3 /tests/grade_qr.py > /tmp/qr_grade_stdout.txt 2>&1 || true
cat /tmp/qr_grade_stdout.txt | tail -30
cp /tmp/qr_grade.json /tmp/qr_grade_stdout.txt /tmp/qr_accuracy.log \
   /logs/verifier/ 2>/dev/null || true

python3 -m pip install --quiet --no-input pytest==8.4.1 pytest-json-ctrf==0.3.5 2>/dev/null || true
python3 -m pytest --ctrf /logs/verifier/ctrf.json /tests/test_outputs.py -rA

if [ $? -eq 0 ]; then
  echo 1 > /logs/verifier/reward.txt
else
  echo 0 > /logs/verifier/reward.txt
fi
