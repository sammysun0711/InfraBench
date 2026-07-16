#!/bin/bash
# dwconv3d-occupancy verifier. Runs in the SAME container as the agent (shared
# mode). Builds + benchmarks a FROZEN trusted original kernel vs the agent's
# edited kernel and gates on correctness + VGPR reduction + >=10% speedup.
set -u

mkdir -p /logs/verifier

python3 /tests/grade_conv.py > /tmp/conv_grade_stdout.txt 2>&1 || true
cat /tmp/conv_grade_stdout.txt | tail -30
cp /tmp/conv_grade.json /tmp/conv_grade_stdout.txt /tmp/agent_run.log /tmp/stock_run.log \
   /logs/verifier/ 2>/dev/null || true

python3 -m pip install --quiet --no-input pytest==8.4.1 pytest-json-ctrf==0.3.5
python3 -m pytest --ctrf /logs/verifier/ctrf.json /tests/test_outputs.py -rA

if [ $? -eq 0 ]; then
  echo 1 > /logs/verifier/reward.txt
else
  echo 0 > /logs/verifier/reward.txt
fi
