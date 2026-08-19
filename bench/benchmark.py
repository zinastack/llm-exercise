#!/usr/bin/env python3
"""Load generator. Streams completions, reports ttft/tpot percentiles.

Must stream or ttft is meaningless. Failures are counted separately so a
config that sheds requests doesn't look fast.
"""
import argparse, asyncio, json, math, os, random, statistics, sys, time
from pathlib import Path

try:
    import aiohttp
except ImportError:
    sys.exit("pip install aiohttp")


def build_prompt(target_tokens: int, seed: int) -> str:
    """~target_tokens of filler. Fixed preamble so prefix caching has
    something to hit, varying body so the prompts aren't identical."""
    rng = random.Random(seed)
    preamble = (
        "You are a careful infrastructure engineer. Answer precisely and "
        "concisely, and prefer concrete mechanisms over generalities. "
    )
    vocab = ("cluster node fabric latency throughput memory bandwidth kernel "
             "scheduler cache tensor parallel pipeline batch token weight "
             "gradient checkpoint topology switch link congestion queue").split()
    n_words = max(8, int(target_tokens * 0.75) - 30)
    body = " ".join(rng.choice(vocab) for _ in range(n_words))
    return f"{preamble}Consider the following notes: {body}. Summarise them."


async def one_request(session, base_url, api_key, model, prompt, max_tokens):
    body = {
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": max_tokens,
        "temperature": 0.0,
        "stream": True,
    }
    headers = {"Authorization": f"Bearer {api_key}"}
    start = time.perf_counter()
    ttft = None
    n_tokens = 0
    try:
        async with session.post(f"{base_url}/chat/completions",
                                json=body, headers=headers) as resp:
            if resp.status != 200:
                return {"ok": False, "reason": f"http_{resp.status}"}
            async for raw in resp.content:
                line = raw.decode("utf-8", "ignore").strip()
                if not line.startswith("data:"):
                    continue
                payload = line[5:].strip()
                if payload == "[DONE]":
                    break
                try:
                    chunk = json.loads(payload)
                except json.JSONDecodeError:
                    continue
                delta = chunk.get("choices", [{}])[0].get("delta", {})
                if delta.get("content"):
                    if ttft is None:
                        ttft = time.perf_counter() - start
                    n_tokens += 1
    except asyncio.TimeoutError:
        return {"ok": False, "reason": "timeout"}
    except Exception as exc:
        return {"ok": False, "reason": type(exc).__name__}

    total = time.perf_counter() - start
    if ttft is None or n_tokens < 2:
        return {"ok": False, "reason": "empty_stream"}
    return {"ok": True, "ttft": ttft, "total": total, "tokens": n_tokens,
            "tpot": (total - ttft) / (n_tokens - 1)}


def pct(xs, p):
    if not xs:
        return float("nan")
    if len(xs) == 1:
        return xs[0]
    xs = sorted(xs)
    k = (len(xs) - 1) * (p / 100.0)
    lo, hi = math.floor(k), math.ceil(k)
    return xs[lo] if lo == hi else xs[lo] + (xs[hi] - xs[lo]) * (k - lo)


async def run_level(cfg, concurrency, n_requests):
    conn = aiohttp.TCPConnector(limit=concurrency + 16)
    timeout = aiohttp.ClientTimeout(total=cfg["timeout"])
    sem = asyncio.Semaphore(concurrency)

    async with aiohttp.ClientSession(connector=conn, timeout=timeout) as session:
        # warmup, discarded
        await one_request(session, cfg["base_url"], cfg["api_key"], cfg["model"],
                          build_prompt(cfg["prompt_tokens"], 0), 16)

        async def guarded(i):
            async with sem:
                return await one_request(
                    session, cfg["base_url"], cfg["api_key"], cfg["model"],
                    build_prompt(cfg["prompt_tokens"], i), cfg["max_tokens"])

        t0 = time.perf_counter()
        results = await asyncio.gather(*[guarded(i) for i in range(n_requests)])
        wall = time.perf_counter() - t0

    ok = [r for r in results if r.get("ok")]
    bad = [r for r in results if not r.get("ok")]
    reasons = {}
    for r in bad:
        reasons[r["reason"]] = reasons.get(r["reason"], 0) + 1

    if not ok:
        return {"concurrency": concurrency, "requests": n_requests,
                "succeeded": 0, "failed": len(bad), "failure_reasons": reasons,
                "note": "all requests failed"}

    ttfts = [r["ttft"] for r in ok]
    tpots = [r["tpot"] for r in ok]
    tokens = sum(r["tokens"] for r in ok)

    return {
        "concurrency": concurrency,
        "requests": n_requests,
        "succeeded": len(ok),
        "failed": len(bad),
        "failure_reasons": reasons,
        "wall_seconds": round(wall, 2),
        "output_tokens": tokens,
        "output_tok_per_s": round(tokens / wall, 1),
        "ttft_ms": {
            "p50": round(pct(ttfts, 50) * 1000, 1),
            "p90": round(pct(ttfts, 90) * 1000, 1),
            "p95": round(pct(ttfts, 95) * 1000, 1),
            "p99": round(pct(ttfts, 99) * 1000, 1),
            "max": round(max(ttfts) * 1000, 1),
        },
        "tpot_ms": {
            "p50": round(statistics.median(tpots) * 1000, 2),
            "p99": round(pct(tpots, 99) * 1000, 2),
        },
    }


async def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base-url", default="http://localhost:8000/v1")
    ap.add_argument("--api-key", default=os.environ.get("API_KEY", ""))
    ap.add_argument("--model", default="target")
    ap.add_argument("--config-name", default="unnamed")
    ap.add_argument("--model-id", default="")
    ap.add_argument("--flags", default="")
    ap.add_argument("--extra-env", default="")
    ap.add_argument("--rationale", default="")
    ap.add_argument("--levels", default="4:64,64:256",
                    help="concurrency:requests pairs")
    ap.add_argument("--prompt-tokens", type=int, default=512)
    ap.add_argument("--max-tokens", type=int, default=256)
    ap.add_argument("--timeout", type=int, default=900)
    ap.add_argument("--out", default="")
    args = ap.parse_args()

    cfg = {"base_url": args.base_url, "api_key": args.api_key,
           "model": args.model, "prompt_tokens": args.prompt_tokens,
           "max_tokens": args.max_tokens, "timeout": args.timeout}

    print(f"\n{args.config_name}")
    print(f"{'conc':>5} {'tok/s':>9} {'ttft p50':>10} {'ttft p95':>10} "
          f"{'ttft p99':>10} {'tpot p50':>10} {'fail':>6}")
    print("-" * 68)

    levels = []
    for pair in args.levels.split(","):
        c, n = pair.split(":")
        row = await run_level(cfg, int(c), int(n))
        levels.append(row)
        if row["succeeded"] == 0:
            print(f"{row['concurrency']:>5} {'ALL FAILED':>9}  {row['failure_reasons']}")
            continue
        t = row["ttft_ms"]
        print(f"{row['concurrency']:>5} {row['output_tok_per_s']:>9.1f} "
              f"{t['p50']:>9.1f}m {t['p95']:>9.1f}m {t['p99']:>9.1f}m "
              f"{row['tpot_ms']['p50']:>9.2f}m {row['failed']:>6}")

    doc = {
        "config": args.config_name,
        "model": args.model_id,
        "flags": args.flags,
        "extra_env": args.extra_env,
        "rationale": args.rationale,
        "workload": {"prompt_tokens": args.prompt_tokens,
                     "max_tokens": args.max_tokens},
        "startup": "ok",
        "levels": levels,
    }
    if args.out:
        p = Path(args.out)
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(json.dumps(doc, indent=2))
        print(f"\nwrote {p}")


if __name__ == "__main__":
    asyncio.run(main())
