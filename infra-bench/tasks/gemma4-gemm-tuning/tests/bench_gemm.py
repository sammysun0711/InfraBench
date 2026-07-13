#!/usr/bin/env python3
"""Benchmark aiter a16w16 GEMM configs and emit per-shape latency JSON.

Runs the tuner's `--run_config` (benchmark-only, no tuning) and parses its
per-shape result table:

    (M, N, K, dtype, bias=...) |   E2E(us) |   Status

Two modes:
  baseline : `-i <untuned.csv> --run_config`      -> default kernel selection
  config   : `--run_config <tuned.csv>`           -> the given tuned config

Writes {shapes: [{mnk, us, status}], total_us, n_ok, n_total} to --out.
"""
import argparse, json, os, re, subprocess, sys

AITER = "/sgl-workspace/aiter"
TUNER = "csrc/gemm_a16w16/gemm_a16w16_tune.py"
# matches: "(1, 10240, 2816, torch.bfloat16, bias=False) |      18.46 |       OK"
ROW = re.compile(
    r"\((\d+),\s*(\d+),\s*(\d+),\s*[^,]+,\s*bias=\w+\)\s*\|\s*([\d.]+|N/A)\s*\|\s*(\w+)"
)

def run_bench(mode, path):
    py = "/opt/venv/bin/python" if os.path.exists("/opt/venv/bin/python") else sys.executable
    if mode == "baseline":
        cmd = [py, TUNER, "-i", path, "--run_config"]
    else:  # config
        cmd = [py, TUNER, "--run_config", path]
    # Run from /tmp so a local sglang/ dir can't shadow imports; aiter is on path.
    r = subprocess.run(cmd, cwd=AITER, capture_output=True, text=True, timeout=1800)
    return r.stdout + "\n" + r.stderr

def parse(out):
    shapes = []
    for m in ROW.finditer(out):
        M, N, K, us, status = m.groups()
        shapes.append({
            "mnk": f"{M},{N},{K}",
            "us": (float(us) if us != "N/A" else None),
            "status": status,
        })
    ok = [s for s in shapes if s["status"] == "OK" and s["us"] is not None]
    total = round(sum(s["us"] for s in ok), 3) if ok else None
    return {
        "shapes": shapes,
        "total_us": total,
        "n_ok": len(ok),
        "n_total": len(shapes),
    }

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--mode", choices=["baseline", "config"], required=True)
    ap.add_argument("--path", required=True, help="untuned csv (baseline) or tuned csv (config)")
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    out = parse(run_bench(a.mode, a.path))
    json.dump(out, open(a.out, "w"), indent=2)
    print(f"[bench:{a.mode}] total_us={out['total_us']} n_ok={out['n_ok']}/{out['n_total']}")
