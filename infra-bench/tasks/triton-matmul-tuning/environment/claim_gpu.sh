#!/usr/bin/env bash
# InfraBench GPU pool allocator (container entrypoint).
#
# Claims one free GPU index from a shared host pool directory by holding an
# flock for the container's entire lifetime, records the index, then keeps the
# container alive. When the container dies the fd closes and the lock releases
# automatically, so a freed GPU is immediately reusable by the next trial — no
# stale locks, no cleanup step needed.
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
