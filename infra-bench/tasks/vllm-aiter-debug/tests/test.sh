#!/bin/bash
# vllm-aiter-debug verifier. Runs in the SAME container as the agent
# (shared mode) so the agent's fix (e.g. /opt/rocm symlink or a patched aiter
# util) persists. Launches AITER=1 and AITER=0 servers itself, profiles for the
# CK FMHA prefill kernel, and gates on 2x TTFT + 2x throughput.
set -u

mkdir -p /logs/verifier

python3 /tests/grade_aiter.py > /tmp/aiter_grade_stdout.txt 2>&1 || true
cat /tmp/aiter_grade_stdout.txt | tail -30
cp /tmp/aiter_grade.json /tmp/aiter_grade_stdout.txt /tmp/srv.log \
   /logs/verifier/ 2>/dev/null || true

python3 -m pip install --quiet --no-input pytest==8.4.1 pytest-json-ctrf==0.3.5 requests 2>/dev/null || \
  pip install --quiet --no-input pytest==8.4.1 pytest-json-ctrf==0.3.5 2>/dev/null || true
python3 -m pytest --ctrf /logs/verifier/ctrf.json /tests/test_outputs.py -rA

if [ $? -eq 0 ]; then
  echo 1 > /logs/verifier/reward.txt
else
  echo 0 > /logs/verifier/reward.txt
fi
