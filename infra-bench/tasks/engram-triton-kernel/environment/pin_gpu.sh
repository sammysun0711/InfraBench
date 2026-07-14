# Sourced by every bash exec via BASH_ENV. Pins the shell (and any HIP/torch
# workload it launches) to the GPU this container claimed at startup.
if [ -r /tmp/claimed_gpu ]; then
  export HIP_VISIBLE_DEVICES="$(cat /tmp/claimed_gpu)"
  export CUDA_VISIBLE_DEVICES="$HIP_VISIBLE_DEVICES"
fi
