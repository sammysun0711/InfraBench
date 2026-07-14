#!/usr/bin/env bash
# InfraBench GPU pool allocator (container entrypoint).
set -u

POOL="${INFRABENCH_GPU_POOL:-/gpu_pool}"
N="${INFRABENCH_GPU_COUNT:-8}"

mkdir -p "$POOL"

for i in $(seq 0 $((N - 1))); do
  exec {fd}>"$POOL/gpu.$i.lock"
  if flock -n "$fd"; then
    echo "$i" > /tmp/claimed_gpu
    echo "[infrabench] claimed GPU $i (pool size $N)"
    exec sleep infinity
  fi
  eval "exec $fd>&-"
done

echo "[infrabench] ERROR: no free GPU available in pool (size $N)" >&2
exit 1
