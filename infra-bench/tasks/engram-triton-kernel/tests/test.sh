#!/bin/bash
# engram-triton verifier: grade the agent's Triton kernel for correctness (vs
# torch ref + tilelang) and speedup (>=60% vs tilelang).
set -u

mkdir -p /logs/verifier

if [ ! -f /app/engram_triton.py ]; then
  echo "[verifier] /app/engram_triton.py not found"
  echo 0 > /logs/verifier/reward.txt; exit 0
fi

# Integrity gate: the tilelang reference tree (which the agent must BEAT) must be
# byte-identical to the build-time snapshot. If the agent slowed or altered the
# reference to game the speedup/correctness gates, this fails the trial. A
# MISSING manifest is treated as a hard failure (an agent could have deleted it),
# not a warning.
if [ ! -f /opt/tilekernels.sha256 ]; then
  echo "[verifier] FATAL: /opt/tilekernels.sha256 manifest missing — cannot verify reference integrity"
  echo 0 > /logs/verifier/reward.txt; exit 0
fi
if ! sha256sum --quiet --check /opt/tilekernels.sha256 > /tmp/tilekernels_check.txt 2>&1; then
  echo "[verifier] TileKernels reference integrity check FAILED (reference was modified):"
  grep -vE "OK$" /tmp/tilekernels_check.txt | head -20
  cp /tmp/tilekernels_check.txt /logs/verifier/ 2>/dev/null || true
  echo 0 > /logs/verifier/reward.txt; exit 0
fi
echo "[verifier] TileKernels reference integrity verified"

PYTHONPATH=/opt/TileKernels python /tests/grade_engram.py > /tmp/grade_stdout.txt 2>&1 || true
cat /tmp/grade_stdout.txt | grep -vE "TileLang:|Loading tilelang|compile" | tail -30
cp /tmp/engram_grade.json /tmp/grade_stdout.txt /logs/verifier/ 2>/dev/null || true

python -m pip install --quiet --no-input pytest==8.4.1 pytest-json-ctrf==0.3.5
python -m pytest --ctrf /logs/verifier/ctrf.json /tests/test_outputs.py -rA

if [ $? -eq 0 ]; then
  echo 1 > /logs/verifier/reward.txt
else
  echo 0 > /logs/verifier/reward.txt
fi
