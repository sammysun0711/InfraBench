input_tokens=4096
output_tokens=5

export SGLANG_TORCH_PROFILER_DIR="${SGLANG_TORCH_PROFILER_DIR:-/app/sgl-profile-results}"

python3 -m sglang.bench_serving \
    --backend sglang \
    --model /models/Qwen3.5-0.8B \
    --host 0.0.0.0 \
    --port 9080 \
    --dataset-name random \
    --random-input-len ${input_tokens} \
    --random-output-len ${output_tokens} \
    --random-range-ratio 1.0 \
    --flush-cache \
    --seed 12345 \
    --num-prompts 4 \
    --warmup-requests 1 \
    --max-concurrency 1 \
    --profile
