# v1 - FP16 deployment, concurrency 4 / 64 / 256

**Model:** `meta-llama/Llama-3.1-70B-Instruct` (unquantized)
**Change from [v0](v1-int4-benchmark.md):** added concurrency **256** rather than
replacing the workload, so v0's numbers stay comparable.

## Why FP16 changes the picture

```
FP16 weights   ~141 GB   →   ~19 GB KV   ≈  59,000 tokens
INT4 weights    ~35 GB   →  ~125 GB KV
```

The constraint that was slack at INT4 is **binding** here.

## Results

| Level | c | tok/s | TTFT p50 | TTFT p99 | TPOT p50 | fail |
|---|---:|---:|---:|---:|---:|---:|
| `fp16-baseline` | - | **did not start** | - | - | - | - |
| `fp16-L1-fit` | 4 | 78.1 | 241 ms | 485 ms | 49.53 ms | 0 |
| `fp16-L1-fit` | 64 | 735.1 | 1050 ms | 6594 ms | 85.92 ms | 0 |
| `fp16-L1-fit` | 256 | 642.5 | **47,962 ms** | 80,016 ms | 133.97 ms | 0 |
| `fp16-L2-kv` | 4 | 77.8 | 248 ms | 580 ms | 50.25 ms | 0 |
| `fp16-L2-kv` | 64 | 742.0 | 1256 ms | 6416 ms | 84.75 ms | 0 |
| `fp16-L2-kv` | 256 | 830.0 | 16,244 ms | 66,640 ms | 206.89 ms | 0 |
| `fp16-L3-schedule` | 4 | 77.8 | 249 ms | 581 ms | 50.23 ms | 0 |
| `fp16-L3-schedule` | 64 | 744.2 | 1340 ms | 6359 ms | 72.90 ms | 0 |
| `fp16-L3-schedule` | 256 | **846.9** | **14,925 ms** | **31,234 ms** | 202.72 ms | 0 |

Engine sizing: `fp16-L1-fit` 48,384 KV tokens (5.91×) ·
`fp16-L2-kv` **96,768 KV tokens** - exactly double, as halving bytes per token
predicts.

## Findings

### 1 · The default configuration is unservable, not merely slow

`fp16-baseline` **refused to start.** vLLM cannot reserve a 128K context window
in ~19 GB of KV cache. Recorded as a result with `"startup": "FAILED"`, not
retried until something succeeded.

**That is the Part 1 answer.**

### 2 · The improvement Part 2 asks for, at concurrency 256

| | L1-fit | L2-kv | L3-schedule | L1 → L3 |
|---|---:|---:|---:|---:|
| Throughput | 642.5 | 830.0 | **846.9** | **+32%** |
| TTFT p50 | 47,962 ms | 16,244 ms | **14,925 ms** | **3.2× faster** |
| TTFT p99 | 80,016 ms | 66,640 ms | **31,234 ms** | **2.6× faster** |

Both metrics improved substantially at the heaviest concurrency. The L2 mechanism
is confirmed exactly - KV cache doubled, which is what `fp8_e5m2` storage predicts.

### 2b · L3 produced the predicted *signature*, not just a better number

`plan.md` stated in advance: *"p99 TTFT improves far more than p50 - because what
is being removed is queueing delay, not compute. If only the mean moves, the
mechanism is not the one described."*

| L2 → L3 at c=256 | change |
|---|---:|
| TTFT **p50** | 8% better |
| TTFT **p99** | **53% better** |

The tail improved more than six times as much as the median. Chunked prefill
removes queueing behind long prefills; it does not make prefill faster. **The
prediction was written before the measurement and the measurement matched it.**

### 3 · The lever does nothing until the constraint binds

| L1 → L2 | c=4 | c=64 | c=256 |
|---|---:|---:|---:|
| throughput | 78.1 → 77.8 | 735 → 742 | **642 → 830** |

Identical change, no effect at 4 or 64, large effect at 256. This validates
[v0](v1-int4-benchmark.md)'s finding rather than contradicting it - and is a more
useful lesson than a lever that always helps.

### 4 · Throughput going *down* is the signature of a starved system

`fp16-L1-fit` drops 735 → 642 tok/s going from c=64 to c=256, while TTFT p50
reaches 48 seconds. Offered load rising while delivered work falls means the
engine is spending time on scheduling and eviction rather than generation.
