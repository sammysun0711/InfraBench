#!/bin/bash
# gluon-a8w8-mfma-att verifier. Runs in the SAME container as the agent (shared
# mode). Re-decodes the agent's ATT trace with a TRUSTED analyzer copy and gates
# on a real MFMA-backed trace + efficiency band + agent-matches-recompute.
set -u

mkdir -p /logs/verifier

python3 /tests/grade_mfma.py > /tmp/mfma_grade_stdout.txt 2>&1 || true
cat /tmp/mfma_grade_stdout.txt | tail -40
cp /tmp/mfma_grade.json /tmp/mfma_grade_stdout.txt /tmp/mfma_recompute.log \
   /logs/verifier/ 2>/dev/null || true

python3 -m pip install --quiet --no-input pytest==8.4.1 pytest-json-ctrf==0.3.5
python3 -m pytest --ctrf /logs/verifier/ctrf.json /tests/test_outputs.py -rA

if [ $? -eq 0 ]; then
  echo 1 > /logs/verifier/reward.txt
else
  echo 0 > /logs/verifier/reward.txt
fi
