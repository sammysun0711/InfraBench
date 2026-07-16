export SGLANG_USE_AITER=1 

python3 -m sglang.launch_server \
	--port 9080 \
	--model-path /models/Qwen3.5-0.8B \
	--tp-size 1 \
	--reasoning-parser qwen3 \
	--tool-call-parser qwen3_coder \
	--enable-multimodal \
	--trust-remote-code \
	--mem-fraction-static 0.8 \
	--attention-backend triton \
	--mm-attention-backend triton_attn \
	--mamba-scheduler-strategy extra_buffer \
	--page-size 64
