This environment runs on an AMD GPU (ROCm). Your task is to detect the GPU
assigned to this container and report information about it.

Write a JSON file to `/app/gpu_report.json` with exactly these fields:

- `visible_device_count` (integer): the number of GPUs PyTorch can see in this
  container. Use `torch.cuda.device_count()`.
- `device_name` (string): the product name of GPU 0, from
  `torch.cuda.get_device_name(0)`.
- `gcn_arch` (string): the GCN architecture name of GPU 0, from
  `torch.cuda.get_device_properties(0).gcnArchName` (e.g. it starts with
  `gfx`).

Requirements:

- The file must be valid JSON parseable by Python's `json.load`.
- `visible_device_count` must be a positive integer reflecting the real number
  of GPUs visible to this container (do not hardcode it — read it at runtime).
- `gcn_arch` must be the real architecture string reported by the driver.
- PyTorch is already installed in the environment.
