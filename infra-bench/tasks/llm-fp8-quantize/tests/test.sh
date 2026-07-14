#!/bin/bash
# A4 verifier. Runs in the SAME container as the agent (shared mode). Measures
# the BF16 baseline (/models/Qwen3.5-27B) and the agent's FP8 model
# (/app/fp8_model) end-to-end with the fixed canonical launch + benchmark
# commands, and gates on throughput improvement + accuracy retention + a real
# FP8 quantization declaration.
set -u

source /tests/bench_lib.sh

mkdir -p /logs/verifier

# Static check: the agent's config must declare an FP8 quantization (a plain
# BF16 copy is rejected). Written for test_outputs.py to read.
python3 - <<'PY'
import json, os
out = {"fp8_declared": False, "why": ""}
cfg = "/app/fp8_model/config.json"
try:
    c = json.load(open(cfg))
    q = c.get("quantization_config", {})
    blob = json.dumps(q).lower()
    out["fp8_declared"] = ("fp8" in blob) or ("float-quantized" in blob) or (
        "num_bits" in blob and '"num_bits": 8' in json.dumps(q))
    out["why"] = f"quantization_config keys: {list(q)}"
except Exception as e:
    out["why"] = f"cannot read {cfg}: {e}"
json.dump(out, open("/tmp/fp8_static.json", "w"), indent=2)
print("[verifier] static:", out)
PY

# 1) BF16 baseline.
measure_model bf16 /models/Qwen3.5-27B /tmp/bf16.json

# 2) Agent FP8 model.
measure_model fp8 /app/fp8_model /tmp/fp8.json

cp /tmp/bf16.json /tmp/fp8.json /tmp/fp8_static.json /logs/verifier/ 2>/dev/null || true

# 3) Gate.
/opt/venv/bin/python -m pip install --quiet --no-input pytest==8.4.1 pytest-json-ctrf==0.3.5
/opt/venv/bin/python -m pytest --ctrf /logs/verifier/ctrf.json /tests/test_outputs.py -rA

if [ $? -eq 0 ]; then
  echo 1 > /logs/verifier/reward.txt
else
  echo 0 > /logs/verifier/reward.txt
fi
