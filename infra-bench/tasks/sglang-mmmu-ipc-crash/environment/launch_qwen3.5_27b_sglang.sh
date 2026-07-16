#!/bin/bash
# Launch the Qwen3.5-27B multimodal sglang server (TP=2) on 2x MI35X.
# This is the configuration that crashes during the MMMU accuracy test.
export SGLANG_USE_AITER=1
export SGLANG_USE_CUDA_IPC_TRANSPORT=1

python3 -m sglang.launch_server \
	--port 9080 \
	--model-path /models/Qwen3.5-27B \
	--tp-size 2 \
	--reasoning-parser qwen3 \
	--tool-call-parser qwen3_coder \
	--enable-multimodal \
	--trust-remote-code \
	--mem-fraction-static 0.8 \
	--attention-backend triton \
	--mm-attention-backend triton_attn \
	--disable-radix-cache \
	2>&1 | tee ./vllm_server_qwen3.5-27b-triton-attn-0.5.15.log
