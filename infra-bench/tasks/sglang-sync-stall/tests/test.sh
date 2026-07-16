#!/bin/bash
# sglang-sync-stall verifier. Runs in the SAME container as the agent (shared
# mode). Launches + torch-profiles the server itself, recomputes GPU-idle% and
# D2H sync-op counts from its own trace, and checks the agent's analysis matches.
set -u

mkdir -p /logs/verifier

python3 /tests/grade_syncstall.py > /tmp/syncstall_grade_stdout.txt 2>&1 || true
cat /tmp/syncstall_grade_stdout.txt | tail -30
cp /tmp/syncstall_grade.json /tmp/syncstall_grade_stdout.txt /tmp/vsrv.log /tmp/vprofile.log \
   /logs/verifier/ 2>/dev/null || true

python3 -m pip install --quiet --no-input pytest==8.4.1 pytest-json-ctrf==0.3.5 2>/dev/null || true
python3 -m pytest --ctrf /logs/verifier/ctrf.json /tests/test_outputs.py -rA

if [ $? -eq 0 ]; then
  echo 1 > /logs/verifier/reward.txt
else
  echo 0 > /logs/verifier/reward.txt
fi
