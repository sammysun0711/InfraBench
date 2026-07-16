#!/bin/bash
# gemm-fp8-ptpc verifier: grade the agent's kernel for PTPC correctness (fresh
# data, several shapes) and an efficiency floor vs the frozen reference kernel.
set -u

mkdir -p /logs/verifier

if [ ! -f /app/gemm_splitk.py ]; then
  echo "[verifier] /app/gemm_splitk.py not found"
  echo 0 > /logs/verifier/reward.txt; exit 0
fi

# Integrity gate: the frozen reference PTPC kernel (used to calibrate the
# efficiency floor) must be byte-identical to the build-time snapshot. If the
# agent slowed or altered it to game the floor, this fails the trial. A MISSING
# manifest is a hard failure (the agent could have deleted it), not a warning.
if [ ! -f /opt/reference_ptpc.sha256 ]; then
  echo "[verifier] FATAL: /opt/reference_ptpc.sha256 manifest missing — cannot verify reference integrity"
  echo 0 > /logs/verifier/reward.txt; exit 0
fi
if ! sha256sum --quiet --check /opt/reference_ptpc.sha256 > /tmp/ref_check.txt 2>&1; then
  echo "[verifier] reference integrity check FAILED (reference was modified):"
  grep -vE "OK$" /tmp/ref_check.txt | head -20
  cp /tmp/ref_check.txt /logs/verifier/ 2>/dev/null || true
  echo 0 > /logs/verifier/reward.txt; exit 0
fi
echo "[verifier] reference integrity verified"

python /tests/grade_ptpc.py > /tmp/grade_stdout.txt 2>&1 || true
grep -vE "WARNING|aiter|NUMA|numa" /tmp/grade_stdout.txt | tail -30
cp /tmp/ptpc_grade.json /tmp/grade_stdout.txt /logs/verifier/ 2>/dev/null || true

python -m pip install --quiet --no-input pytest==8.4.1 pytest-json-ctrf==0.3.5
python -m pytest --ctrf /logs/verifier/ctrf.json /tests/test_outputs.py -rA

if [ $? -eq 0 ]; then
  echo 1 > /logs/verifier/reward.txt
else
  echo 0 > /logs/verifier/reward.txt
fi
