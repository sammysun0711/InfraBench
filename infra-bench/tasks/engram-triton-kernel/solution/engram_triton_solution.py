"""Oracle Triton implementation of the Engram gate forward pass.

One program per token; all heads handled in a static loop with v loaded once and
reused across heads. Memory-bandwidth-bound op — this reaches ~88% of achievable
HBM bandwidth on MI350 (~66-67% faster than the TileLang reference).
"""
import torch
import triton
import triton.language as tl


@triton.jit
def _engram_gate_fwd_kernel(
    x_ptr, k_ptr, v_ptr, wf_ptr, out_ptr,
    dot_ptr, gate_ptr, rstdx_ptr, rstdk_ptr,
    HC: tl.constexpr, H: tl.constexpr, eps, clamp, scalar,
    SAVE: tl.constexpr, BLK: tl.constexpr,
):
    tok = tl.program_id(0)
    o = tl.arange(0, BLK)
    v = tl.load(v_ptr + tok * H + o).to(tl.float32)  # shared across heads
    for h in tl.static_range(0, HC):
        base = tok * HC * H + h * H
        x = tl.load(x_ptr + base + o).to(tl.float32)
        kk = tl.load(k_ptr + base + o).to(tl.float32)
        wf = tl.load(wf_ptr + h * H + o).to(tl.float32)
        rstd_x = 1.0 / tl.sqrt(tl.sum(x * x) / H + eps)
        rstd_k = 1.0 / tl.sqrt(tl.sum(kk * kk) / H + eps)
        raw_dot = tl.sum(x * kk * wf)
        dot = raw_dot * rstd_x * rstd_k * scalar
        ad = tl.abs(dot)
        ad = tl.where(ad < clamp, clamp, ad)
        gate = 1.0 / (1.0 + tl.exp(-(tl.sqrt(ad) * tl.where(dot >= 0, 1.0, -1.0))))
        tl.store(out_ptr + base + o, (x + gate * v).to(tl.bfloat16))
        if SAVE:
            tl.store(dot_ptr + tok * HC + h, raw_dot)
            tl.store(gate_ptr + tok * HC + h, gate)
            tl.store(rstdx_ptr + tok * HC + h, rstd_x)
            tl.store(rstdk_ptr + tok * HC + h, rstd_k)


def engram_gate_fwd_triton(hidden_states, k, v, weight_fused, eps, clamp_value,
                           save_for_backward=True):
    nt, hc, H = hidden_states.shape
    scalar = H ** -0.5
    out = torch.empty_like(hidden_states)
    BLK = triton.next_power_of_2(H)
    if save_for_backward:
        dot = torch.empty(nt, hc, dtype=torch.float32, device=hidden_states.device)
        gate = torch.empty_like(dot)
        rstd_x = torch.empty_like(dot)
        rstd_k = torch.empty_like(dot)
    else:
        dot = gate = rstd_x = rstd_k = None
    _engram_gate_fwd_kernel[(nt,)](
        hidden_states, k, v, weight_fused, out,
        dot if save_for_backward else out,
        gate if save_for_backward else out,
        rstd_x if save_for_backward else out,
        rstd_k if save_for_backward else out,
        hc, H, eps, clamp_value, scalar, save_for_backward, BLK, num_warps=4,
    )
    return out, dot, gate, rstd_x, rstd_k
