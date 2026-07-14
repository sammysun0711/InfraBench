#!/bin/bash
# Verifier entrypoint for llvm-simple-constant-propagation.
set -u

mkdir -p /logs/verifier

python3 /tests/grade_constant_propagation.py > /tmp/grade_stdout.txt 2>&1 || true
cat /tmp/grade_stdout.txt | tail -100
cp /tmp/llvm_constprop_grade.json /tmp/grade_stdout.txt /logs/verifier/ 2>/dev/null || true

python3 -m pip install --quiet --no-input --break-system-packages pytest==8.4.1 pytest-json-ctrf==0.3.5
python3 -m pytest --ctrf /logs/verifier/ctrf.json /tests/test_outputs.py -rA

if [ $? -eq 0 ]; then
  echo 1 > /logs/verifier/reward.txt
else
  echo 0 > /logs/verifier/reward.txt
fi
