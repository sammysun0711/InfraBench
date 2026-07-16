#!/usr/bin/env bash
# InfraBench GPU pool allocator (container entrypoint) — MULTI-GPU capable.
#
# Claims INFRABENCH_GPU_CLAIM (default 1) free GPU indices from a shared host
# pool directory by holding an flock on each for the container's whole lifetime,
# records the comma-joined list, then keeps the container alive. When the
# container dies all fds close and the locks release automatically — freed GPUs
# are immediately reusable by the next trial, and two concurrent multi-GPU trials
# can never grab the same card (flock arbitration is per-index).
set -u

POOL="${INFRABENCH_GPU_POOL:-/gpu_pool}"
N="${INFRABENCH_GPU_COUNT:-8}"
NEED="${INFRABENCH_GPU_CLAIM:-1}"

mkdir -p "$POOL"

claimed=()
fds=()
for i in $(seq 0 $((N - 1))); do
  exec {fd}>"$POOL/gpu.$i.lock"
  if flock -n "$fd"; then
    claimed+=("$i")
    fds+=("$fd")
    if [ "${#claimed[@]}" -eq "$NEED" ]; then
      list="$(IFS=,; echo "${claimed[*]}")"
      echo "$list" > /tmp/claimed_gpu
      echo "[infrabench] claimed GPU(s) $list (need $NEED, pool size $N)"
      exec sleep infinity
    fi
  else
    eval "exec $fd>&-"
  fi
done

echo "[infrabench] ERROR: could not claim $NEED free GPU(s) in pool (size $N); got ${claimed[*]:-none}" >&2
exit 1
