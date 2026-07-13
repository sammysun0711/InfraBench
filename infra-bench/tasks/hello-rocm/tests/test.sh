#!/bin/bash
# Verifier entrypoint. Runs in the SAME container as the agent (shared mode), so
# BASH_ENV has already pinned HIP_VISIBLE_DEVICES to the claimed GPU and the
# image's torch is importable.

# Use the base image's Python (has torch); add pytest + ctrf reporter.
PY=/opt/venv/bin/python
$PY -m pip install --quiet --no-input pytest==8.4.1 pytest-json-ctrf==0.3.5

$PY -m pytest --ctrf /logs/verifier/ctrf.json /tests/test_outputs.py -rA

if [ $? -eq 0 ]; then
  echo 1 > /logs/verifier/reward.txt
else
  echo 0 > /logs/verifier/reward.txt
fi
