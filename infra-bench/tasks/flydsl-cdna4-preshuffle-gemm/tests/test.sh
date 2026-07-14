#!/bin/bash
# Verifier entrypoint for the FlyDSL CDNA4 preshuffle GEMM port.
set -u

mkdir -p /logs/verifier

if [ ! -f /app/04-preshuffle_gemm.py ]; then
  echo "[verifier] /app/04-preshuffle_gemm.py not found"
  echo 0 > /logs/verifier/reward.txt
  exit 0
fi

python /tests/grade_preshuffle_gemm.py > /tmp/grade_stdout.txt 2>&1 || true
cat /tmp/grade_stdout.txt | tail -80
cp /tmp/preshuffle_gemm_grade.json /tmp/preshuffle_gemm_perf.json /tmp/grade_stdout.txt /logs/verifier/ 2>/dev/null || true

python -m pip install --quiet --no-input pytest==8.4.1 pytest-json-ctrf==0.3.5
python -m pytest --ctrf /logs/verifier/ctrf.json /tests/test_outputs.py -rA

if [ $? -eq 0 ]; then
  echo 1 > /logs/verifier/reward.txt
else
  echo 0 > /logs/verifier/reward.txt
fi
