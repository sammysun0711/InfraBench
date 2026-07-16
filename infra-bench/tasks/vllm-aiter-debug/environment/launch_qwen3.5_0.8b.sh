#!/bin/bash

export VLLM_ROCM_USE_AITER=1

python3 -m vllm.entrypoints.openai.api_server \
      --profiler-config '{"profiler": "torch", "torch_profiler_dir": "./vllm_profile_result"}' \
      --attention-config '{"backend": "ROCM_AITER_FA"}' \
      --model /models/Qwen3.5-0.8B \
      --port 32000 \
      --host 0.0.0.0 \
      --tensor-parallel-size 1 \
      --trust-remote-code \
      --no-enable-prefix-caching \
      --gpu-memory-utilization 0.8 \
      2>&1 | tee ./vllm_server_qwen3.5-8b-aiter.log

