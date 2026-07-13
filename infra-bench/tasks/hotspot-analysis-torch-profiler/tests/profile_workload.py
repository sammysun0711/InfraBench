#!/usr/bin/env python3
"""Canonical B1 profiling workload + trace parser.

Drives a fixed, deterministic inference against an already-running sglang server
(8192 input tokens / 5 output / concurrency 1) while sglang's torch profiler is
active, then aggregates the resulting chrome trace by GPU kernel.

Usage:
  # 1) profile the running server -> writes a .trace.json.gz into PROF_DIR
  python profile_workload.py profile --prof-dir /tmp/prof --port 30000
  # 2) parse the newest trace in PROF_DIR -> prints/writes hotspot JSON
  python profile_workload.py parse --prof-dir /tmp/prof --out /tmp/hotspot.json

The workload token pattern is FIXED so the baseline (verifier) and the agent
profile exactly the same computation.
"""
import argparse, collections, glob, gzip, json, os, subprocess, sys
import urllib.request

# Fixed workload: 4 requests, 8192 input / 5 output, concurrency 1. Multiple
# requests average out single-shot profiling noise so the per-kernel % is
# reproducible (single 5-token request drifts ~10pt run-to-run; 4 requests
# drift <1pt).
INPUT_LEN = 8192
OUTPUT_LEN = 5
NUM_PROMPT = 4

def cmd_profile(args):
    os.makedirs(args.prof_dir, exist_ok=True)
    # bench_serving --profile toggles /start_profile + /stop_profile around the
    # run and writes the trace under SGLANG_TORCH_PROFILER_DIR.
    env = dict(os.environ, SGLANG_TORCH_PROFILER_DIR=args.prof_dir, HF_HUB_OFFLINE="0")
    # Use the venv python that has sglang (sys.executable may be system python).
    py = "/opt/venv/bin/python" if os.path.exists("/opt/venv/bin/python") else sys.executable
    cmd = [
        py, "-m", "sglang.bench_serving", "--backend", "sglang",
        "--dataset-name", "random", "--profile",
        "--num-prompt", str(NUM_PROMPT), "--max-concurrency", "1",
        "--port", str(args.port),
        "--random-input-len", str(INPUT_LEN), "--random-output-len", str(OUTPUT_LEN),
        "--random-range-ratio", "1.0",
    ]
    # Run from /tmp so Python does not shadow the installed `sglang` package with
    # a local `sglang/` dir (e.g. if CWD were /sgl-workspace/python) — that makes
    # `python -m sglang.bench_serving` fail to import sglang.benchmark.serving.
    r = subprocess.run(cmd, env=env, cwd="/tmp", capture_output=True, text=True, timeout=1200)
    print("[profile] bench_serving rc=", r.returncode)
    # trace lands in a timestamped subdir under prof_dir
    traces = glob.glob(os.path.join(args.prof_dir, "**", "*.trace.json.gz"), recursive=True)
    print(f"[profile] traces: {traces}")
    sys.exit(0 if traces else 1)

def parse_trace(prof_dir):
    traces = sorted(
        glob.glob(os.path.join(prof_dir, "**", "*.trace.json.gz"), recursive=True),
        key=os.path.getmtime,
    )
    assert traces, f"no trace found in {prof_dir}"
    ev = json.load(gzip.open(traces[-1]))
    ev = ev["traceEvents"] if isinstance(ev, dict) else ev
    kt = collections.defaultdict(float)
    for e in ev:
        if e.get("cat") == "kernel" and "dur" in e:
            kt[e["name"]] += e["dur"]
    total = sum(kt.values())
    ranked = sorted(kt.items(), key=lambda x: -x[1])
    return {
        "kernel": ranked[0][0],
        "pct": round(100 * ranked[0][1] / total, 2),
        "total_gpu_ms": round(total / 1000, 2),
        "top5": [(n, round(100 * t / total, 2)) for n, t in ranked[:5]],
    }

def cmd_parse(args):
    result = parse_trace(args.prof_dir)
    if args.out:
        json.dump(result, open(args.out, "w"), indent=2)
    print(json.dumps(result, indent=2))

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("profile"); p.add_argument("--prof-dir", required=True); p.add_argument("--port", type=int, default=30000)
    q = sub.add_parser("parse");   q.add_argument("--prof-dir", required=True); q.add_argument("--out", default="")
    args = ap.parse_args()
    (cmd_profile if args.cmd == "profile" else cmd_parse)(args)
