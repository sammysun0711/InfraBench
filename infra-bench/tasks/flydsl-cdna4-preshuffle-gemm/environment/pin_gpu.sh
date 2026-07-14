# Sourced by every bash exec via BASH_ENV. Pins HIP/torch workloads to the
# container's claimed GPU.
if [ -r /tmp/claimed_gpu ]; then
  export HIP_VISIBLE_DEVICES="$(cat /tmp/claimed_gpu)"
  export CUDA_VISIBLE_DEVICES="$HIP_VISIBLE_DEVICES"
fi
