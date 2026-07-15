#!/bin/bash
# Verifier entrypoint for cute-layout-composition.
set -u

mkdir -p /logs/verifier

python3 /tests/grade_cute_layout.py > /tmp/cute_layout_grade_stdout.txt 2>&1 || true
cat /tmp/cute_layout_grade_stdout.txt | tail -120
cp /tmp/cute_layout_grade.json /tmp/cute_layout_grade_stdout.txt /logs/verifier/ 2>/dev/null || true

python3 -m pip install --quiet --no-input pytest==8.4.1 pytest-json-ctrf==0.3.5
python3 -m pytest --ctrf /logs/verifier/ctrf.json /tests/test_outputs.py -rA

if [ $? -eq 0 ]; then
  echo 1 > /logs/verifier/reward.txt
else
  echo 0 > /logs/verifier/reward.txt
fi
