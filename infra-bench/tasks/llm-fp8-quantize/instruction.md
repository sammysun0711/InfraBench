You are optimizing LLM inference cost on an AMD MI35X (CDNA4, gfx950) GPU by
**quantizing a model to FP8** and serving it with sglang, without giving up
accuracy.

## Background

The BF16 checkpoint `/models/Qwen3.5-27B` is served today with sglang. FP8
(E4M3) weights + dynamic activations can cut memory traffic and raise
throughput on MI350's FP8 matrix engines — but only if the quantization is
done correctly. Get it wrong and the model either fails to serve or produces
garbage.

## Goal

Produce an **FP8-quantized copy** of `/models/Qwen3.5-27B` that:

1. **serves** under sglang on this GPU, and
2. is at least **10% faster** than the BF16 model on a long-context workload
   (8192-token input / 1024-token output, concurrency 8), measured as total
   token throughput (tok/s), and
3. keeps **GSM8K accuracy within 3 percentage points** of the BF16 model
   (i.e. `bf16_score - fp8_score <= 0.03`).

## Deliverable

Write your quantized model to the directory **`/app/fp8_model`** so that

```
python -m sglang.launch_server --model /app/fp8_model --disable-radix-cache \
    --host 0.0.0.0 --port 30000
```

launches a healthy server. Everything the server needs (weights, config,
tokenizer) must live in that directory.

## How you are graded

The grader itself, using fixed canonical commands:

1. serves the BF16 baseline `/models/Qwen3.5-27B` and measures its throughput
   (`sglang.bench_serving`, random 8192/1024, num-prompt 128, concurrency 8)
   and GSM8K score (`sgl-eval`, 200 examples), then
2. serves **your** `/app/fp8_model` and measures the same two metrics, then
3. requires: FP8 total throughput **at least 10% higher** than BF16, AND
   FP8 GSM8K within 3 points of BF16, AND your model's `config.json` actually
   declares an FP8 quantization (a copy of the BF16 weights is rejected).

## Notes and hints

- The GPU assigned to this container is pre-selected; use the default device
  (`HIP_VISIBLE_DEVICES` is already pinned).
- This is a **dense** model with hybrid attention (standard full-attention
  layers interleaved with linear/recurrent-attention blocks). The recurrent
  `linear_attn` path is numerically sensitive — quantizing it tends to destroy
  accuracy. Choose your quantization scope carefully.
- The base image ships sglang, ROCm PyTorch, and `aiter`. You have internet to
  install a quantization toolkit (e.g. `llmcompressor` / `compressed-tensors`,
  or AMD `quark`). Be careful not to disturb the installed ROCm PyTorch build.
- sglang loads FP8 in the `compressed-tensors` (float-quantized) format
  natively. Make sure your output `config.json` keeps the model's original
  architecture and nested text-config structure.
