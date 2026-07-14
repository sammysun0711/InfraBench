#!/bin/bash
# hipify verifier: build the agent's ported extension, then check op-level +
# end-to-end numerics against captured references. Reward 1 iff build succeeds
# AND all numeric checks pass.
set -u

mkdir -p /logs/verifier

# 1) Build the agent's (fixed) extension from the in-place source tree.
echo "[verifier] building /app/pointnet2_ops_lib ..."
if ! pip install --no-build-isolation -e /app/pointnet2_ops_lib > /tmp/build.log 2>&1; then
  echo "[verifier] BUILD FAILED"; tail -20 /tmp/build.log
  cp /tmp/build.log /logs/verifier/ 2>/dev/null || true
  echo 0 > /logs/verifier/reward.txt; exit 0
fi
echo "[verifier] build OK"

# 2) Numerical + e2e checks (fresh process so the freshly-built ext is imported).
python /tests/check_numerics.py > /tmp/numerics_stdout.txt 2>&1 || true
cat /tmp/numerics_stdout.txt
cp /tmp/numerics.json /tmp/numerics_stdout.txt /tmp/build.log /logs/verifier/ 2>/dev/null || true

# 3) Gate via pytest.
python -m pip install --quiet --no-input pytest==8.4.1 pytest-json-ctrf==0.3.5
python -m pytest --ctrf /logs/verifier/ctrf.json /tests/test_outputs.py -rA

if [ $? -eq 0 ]; then
  echo 1 > /logs/verifier/reward.txt
else
  echo 0 > /logs/verifier/reward.txt
fi
