# v0 - INT4 deployment, concurrency 4 / 64

**Model:** `hugging-quants/Meta-Llama-3.1-70B-Instruct-AWQ-INT4`
**Workload:** 512-token prompts, 256-token outputs, streaming, temperature 0

## Results

| Level | c | tok/s | TTFT p50 | TTFT p99 | TPOT p50 | fail |
|---|---:|---:|---:|---:|---:|---:|
| `baseline` | 4 | 189.6 | 202 ms | 654 ms | 19.87 ms | 0 |
| `baseline` | 64 | 879.6 | 1234 ms | 8223 ms | 73.14 ms | 0 |
| `L2-kv` | 4 | 187.7 | 209 ms | 664 ms | 20.37 ms | 0 |
| `L2-kv` | 64 | 905.5 | 1196 ms | 7415 ms | 69.24 ms | 0 |
| `L3-schedule` | 4 | 185.7 | 208 ms | 664 ms | 20.41 ms | 0 |
| `L3-schedule` | 64 | **907.0** | 1934 ms | 7517 ms | 55.46 ms | 0 |
| `nvlink-off` | 64 | 720.8 | 2585 ms | 13795 ms | 68.82 ms | 0 |

Engine sizing: `baseline` 347,824 KV tokens (2.65× at 131,072/req) ·
`L2-kv` 726,832 KV tokens (88.72× at 8,192/req)

## Findings

### 1 · The tuning barely moved anything - 879.6 → 907.0 tok/s, about 3%

**The levers were not wrong; the constraint was not binding.** At 768 tokens per
request against a 347,000-token cache, the baseline could hold roughly 450
concurrent requests. At concurrency 64 the system was **nowhere near KV-limited**,
so every KV-oriented lever had nothing to act on.

The diagnostic was pairing `gpu_cache_usage_perc` with `num_preemptions_total`:
cache utilisation low, preemptions zero. **A system evicting nothing is not short
of cache.**

**Response: change the workload, not the flags.** Concurrency 256 added in
[v1](v2-fp16-benchmark.md).

### 2 · L3 improved one metric and hurt another

TPOT improved ~20% (69.24 → 55.46 ms) while **TTFT p50 got ~62% worse**
(1196 → 1934 ms), with throughput flat.

Chunked prefill interleaves prefill with decode: individual prefills complete
later, but decode stops being blocked. **The documentation predicted both metrics
would improve. The measurement disagreed, and the documentation was corrected.**

### 3 · NVLink cost scales with batch size

At c=64, disabling P2P cost **−20.5% throughput** and **+84% TTFT p99**.
At c=4 the same comparison showed −2% and unchanged TPOT.

The all-reduce payload grows with batch, so a lightly loaded server barely
notices while a saturated one loses a fifth of its throughput.

## Scope correction

This deployment was originally framed as a *tuning level* named `L2-quantize`.
The exercise states weights must not be modified, and quantization changes
weights. Renamed `L2-kv` (the KV cache *format* changed, not the model) and the
quantized checkpoint was re-scoped as the served model rather than a lever.
