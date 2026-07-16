#!/bin/bash
# Run the MMMU multimodal accuracy benchmark against the running sglang server.
# This is the workload that triggers the crash on the unfixed configuration.
python3 /sgl-workspace/sglang/benchmark/mmmu/bench_sglang.py \
	--concurrency 128 \
	--port 9080 \
	--max-new-tokens 512 \
	2>&1 | tee run_mmmu.log
