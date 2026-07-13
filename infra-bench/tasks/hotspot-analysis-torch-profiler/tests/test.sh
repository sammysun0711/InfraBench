#!/bin/bash
# B1 verifier. Launches the sglang server, profiles the SAME fixed 8K/5 workload
# the agent was given, parses the trace for the ground-truth top GPU kernel, and
# checks the agent's /app/hotspot.json against it.
set -u

mkdir -p /logs/verifier /tmp/verifier_prof

# 1) Launch server (canonical command; SGLANG_TORCH_PROFILER_DIR set in image).
pkill -9 -f sglang 2>/dev/null; pkill -9 -f launch_server 2>/dev/null; sleep 4
SGLANG_TORCH_PROFILER_DIR=/tmp/verifier_prof \
  python -m sglang.launch_server --model /models/gemma-4-26B-A4B-it \
    --disable-radix-cache --host 0.0.0.0 --port 30000 > /tmp/verifier_srv.log 2>&1 &

ok=0
for i in $(seq 1 96); do
  if curl -s -m 5 http://0.0.0.0:30000/health_generate >/dev/null 2>&1; then ok=1; break; fi
  grep -qE "address already in use|Fatal Python error|CUDA error|HIP error|Traceback" /tmp/verifier_srv.log 2>/dev/null && break
  sleep 5
done
if [ "$ok" != 1 ]; then
  echo "[verifier] server not healthy"; tail -8 /tmp/verifier_srv.log
  echo 0 > /logs/verifier/reward.txt; exit 0
fi

# 2) Profile the fixed workload + parse ground truth (venv python has sglang).
/opt/venv/bin/python /tests/profile_workload.py profile --prof-dir /tmp/verifier_prof --port 30000
/opt/venv/bin/python /tests/profile_workload.py parse --prof-dir /tmp/verifier_prof --out /tmp/ground_truth.json
cp /tmp/ground_truth.json /logs/verifier/ 2>/dev/null || true
cp /app/hotspot.json /logs/verifier/agent_hotspot.json 2>/dev/null || true

pkill -9 -f sglang 2>/dev/null; pkill -9 -f launch_server 2>/dev/null

# 3) Gate.
/opt/venv/bin/python -m pip install --quiet --no-input pytest==8.4.1 pytest-json-ctrf==0.3.5
/opt/venv/bin/python -m pytest --ctrf /logs/verifier/ctrf.json /tests/test_outputs.py -rA

if [ $? -eq 0 ]; then
  echo 1 > /logs/verifier/reward.txt
else
  echo 0 > /logs/verifier/reward.txt
fi
