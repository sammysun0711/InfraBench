#!/bin/bash
# sglang-mmmu-ipc-crash verifier. Runs in the SAME container as the agent (shared
# mode). Launches the agent's fixed launch script, reads the live scheduler env,
# runs the MMMU benchmark itself, and checks the agent's analysis + config.
set -u

mkdir -p /logs/verifier

python3 /tests/grade_ipc.py > /tmp/ipc_grade_stdout.txt 2>&1 || true
tail -40 /tmp/ipc_grade_stdout.txt
cp /tmp/ipc_grade.json /tmp/ipc_grade_stdout.txt /tmp/vsrv.log /tmp/vmmmu.log \
   /logs/verifier/ 2>/dev/null || true

python3 -m pip install --quiet --no-input pytest==8.4.1 pytest-json-ctrf==0.3.5 2>/dev/null || true
python3 -m pytest --ctrf /logs/verifier/ctrf.json /tests/test_outputs.py -rA

if [ $? -eq 0 ]; then
  echo 1 > /logs/verifier/reward.txt
else
  echo 0 > /logs/verifier/reward.txt
fi
