"""Implement the Engram gate forward pass as a Triton kernel.

Fill in `engram_gate_fwd_triton` below with a real Triton kernel. The grader
imports THIS function and compares it against both the PyTorch reference and the
DeepSeek TileLang kernel for correctness, then times it against the TileLang
kernel for speedup.

Do NOT change the function name or signature.
"""
import torch
import triton
import triton.language as tl


# TODO: implement your Triton kernel(s) here.


def engram_gate_fwd_triton(
    hidden_states: torch.Tensor,   # (num_tokens, hc_mult, hidden_size), bfloat16
    k: torch.Tensor,               # (num_tokens, hc_mult, hidden_size), bfloat16
    v: torch.Tensor,               # (num_tokens, hidden_size), bfloat16
    weight_fused: torch.Tensor,    # (hc_mult, hidden_size), float32  (= weight_hidden * weight_embed)
    eps: float,
    clamp_value: float,
    save_for_backward: bool = True,
):
    """Engram gate forward.

    Computes, per (token, head):
        rstd_x  = rsqrt(mean(x^2, dim=-1) + eps)
        rstd_k  = rsqrt(mean(k^2, dim=-1) + eps)
        raw_dot = sum(x * k * weight_fused, dim=-1)
        dot     = raw_dot * rstd_x * rstd_k * hidden_size**-0.5
        gate    = sigmoid( sign(dot) * sqrt(clamp_min(|dot|, clamp_value)) )
        out     = (x + gate * v).bfloat16()          # v is shared across heads

    Returns:
        (output, dot, gate_score, rstd_x, rstd_k)
        When save_for_backward is False, the last four are None and only `output`
        is required to be correct.
        When True, dot=raw_dot, gate_score, rstd_x, rstd_k are (num_tokens, hc_mult)
        float32 tensors.
    """
    raise NotImplementedError("implement the Triton engram gate forward kernel")
