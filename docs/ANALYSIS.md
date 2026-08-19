# Analysis

> Deliverable 3. The reasoning is worked through; **the numbers come from
> `RESULTS.md`.** Fill the bracketed figures from your own runs and delete any
> claim the data doesn't support - a prediction that didn't hold is a more
> interesting finding than one that did, and it should be reported as such.

---

## 1 · Baseline deployment

**Configuration:** Llama-3.1-70B-Instruct, FP16, `--tensor-parallel-size 2`,
otherwise vLLM defaults. 2× A100 80GB, NVLink `NV12`.

### The binding constraint

| | |
|---|---|
| FP16 weights | ~140 GB |
| Two A100 80GB | 160 GB |
| Remaining for KV cache | **~20 GB total** |

Llama 3.1 advertises a **128K context window**, and vLLM sizes its KV allocation
against `max_model_len`. With ~20 GB of headroom the engine cannot reserve
anything close to one full-length sequence.

> **`[Record what actually happened: did the container start? If vLLM refused
> with "max seq len is larger than the maximum number of tokens that can be
> stored in KV cache", that refusal IS the first result - the default
> configuration is not merely slow, it is unservable.]`**

Whatever the outcome, the startup log line reporting **GPU KV cache size** and
**maximum concurrency** is the most informative number in the whole exercise.
It is captured per-config in `bench/out/<name>.startup.txt`.

### Baseline behaviour under load

`[From RESULTS.md - throughput and TTFT at concurrency 4 and 64, plus the
failure count at 64.]`

The expected shape: acceptable at concurrency 4, and at concurrency 64 a
collapse in TTFT tail with requests queueing, because the batch the engine can
admit is far smaller than the offered load. **Watch specifically whether p99
TTFT diverges from p50** - a widening gap is queueing, not slow compute.

---

## 2 · What had the biggest impact on throughput

**Expected answer: INT4 weight quantization (`awq`), by a wide margin.**

The mechanism is not "smaller weights are faster to compute." It is that weights
and KV cache compete for the same HBM:

| | Weights | KV headroom |
|---|---|---|
| FP16 | ~140 GB | ~20 GB |
| **INT4 AWQ** | **~35 GB** | **~125 GB** |

Roughly **six times the KV headroom**, which translates almost directly into
concurrent sequences. Throughput in a decode-bound regime is set by how many
sequences share each forward pass - one weight read amortised across N
sequences instead of one. Batch size *is* throughput here.

Two supporting levers, both simpler to apply:

- **`--max-model-len 8192`** - reserving 128K of context per sequence when the
  workload uses 512-token prompts is the single most wasteful default in the
  stack. Expect a large gain for a one-word change.
- **`--kv-cache-dtype fp8`** - halves bytes per token of KV. *Verify this is
  supported on sm80 in the vLLM build you use; A100 has no native FP8 compute,
  and support here is for the storage format only.*

> **A100 cannot use FP8 weights.** Compute capability 8.0. On Hopper or Ada the
> natural first move would be FP8 weights; here the equivalent lever is INT4
> AWQ. Worth naming explicitly - it shows the recommendation is hardware-aware
> rather than copied from a blog post.

`[Report the measured ranking. If max-model-len beat quantization, say so and
explain why - it would mean the workload was context-bound rather than
weight-bound.]`

---

## 3 · What had the biggest impact on TTFT

**Expected answer: `--enable-chunked-prefill`, at the heavy concurrency level.**

TTFT is dominated by how long a request waits before its prefill runs, not by
how long prefill takes. Without chunking, a long prefill occupies the engine as
a single unit and every in-flight decode stalls behind it; new arrivals wait for
the whole thing.

Chunked prefill splits prefill into token-budgeted pieces and interleaves them
with decode steps. Queueing delay drops, so **p99 TTFT should improve far more
than p50** - and that difference is the evidence for the mechanism. If only the
mean moved, the explanation is something else.

**`--enable-prefix-caching`** is the second TTFT lever and its size depends
entirely on workload shape. The benchmark uses a fixed shared preamble plus
varying body, so there is a real prefix to hit but not an artificially large
one. `[Report the delta. With a fully shared system prompt the effect would be
much larger - worth stating, since production RAG and agent workloads look far
more like that than like this benchmark.]`

Note that quantization also improves TTFT indirectly: a bigger KV budget means
fewer requests waiting for cache blocks to free.

---

## 4 · Where a change improved one metric and hurt the other

**The central tension: batch size raises throughput and hurts TTFT.**

Admitting more sequences per forward pass amortises the weight read across more
work - throughput up. But each admitted request now waits behind more work, and
prefill competes with a larger decode batch - TTFT up. Two dials expose this
directly:

| Dial | Raising it |
|---|---|
| `--max-num-seqs` | More throughput, worse TTFT tail |
| `--max-num-batched-tokens` | More throughput, worse TTFT tail |

`[Report where you saw it. The clearest signature is a config with the best
tok/s and a worse p99 TTFT than the config before it.]`

**How to reason about it:** the honest resolution is that raw throughput is the
wrong objective. What matters is **goodput under an SLO** - tokens per second
delivered at a TTFT the user will accept. Throughput at unacceptable latency is
worthless, and a system tuned purely for tok/s will happily produce it.

So the question is not "which config is fastest" but "which config maximises
throughput subject to p99 TTFT under `[state your target - e.g. 1 s]`."
`[Name the config that wins under that constraint, and note that a different
SLO would select a different config.]`

A second, subtler trade: **chunked prefill can cost a little raw throughput**
while improving TTFT, because interleaving is less efficient than running
prefill as one large batched operation. `[If you observed this, it is a good
example - it is a deliberate exchange of efficiency for fairness.]`

---

## 5 · How NVLink matters here, and what changes without it

### Why TP=2 is communication-heavy

Tensor parallelism splits each layer across both GPUs, and correctness requires
an **all-reduce after the attention block and after the MLP block** - two per
transformer layer. Llama-70B has **80 layers**, so a single forward pass performs
roughly **160 all-reduces**.

The two phases stress the interconnect differently:

| Phase | Payload | Sensitive to |
|---|---|---|
| **Prefill** | Large - full prompt's activations | **Bandwidth** |
| **Decode** | Tiny - one token per sequence | **Latency**, paid 160× per token |

**Decode is the sensitive phase**, and not for the obvious reason. The data
moved per all-reduce is small; what hurts is paying the synchronisation cost 160
times to produce a single token. Decode is already memory-bandwidth-bound with
very little compute to hide communication behind, so interconnect latency lands
directly on TPOT.

| Path | Bidirectional bandwidth |
|---|---|
| **NVLink 3.0, 12 links (`NV12`)** | **600 GB/s** |
| PCIe Gen4 x16 | ~64 GB/s |
| No P2P - host memory staging | Lower again, plus a CPU round trip |

### Measured, not assumed

`awq-nop2p` is identical to `awq-tuned` except for `NCCL_P2P_DISABLE=1`, which
forces NCCL off the direct GPU-to-GPU path and through host memory. That gives
an empirical answer instead of an estimate.

`[Report the deltas from the NVLink section of RESULTS.md. Expect TPOT to
degrade more than TTFT in relative terms, because decode pays the per-layer
latency 160 times per token while prefill pays it once per request.]`

**Caveat worth stating:** disabling P2P is a *lower bound* on what removing
NVLink would do - real PCIe-connected A100s would still have P2P over PCIe,
which sits between the two cases measured here. The experiment brackets the
answer rather than reproducing it exactly.

### The architectural consequence

**Without NVLink, TP=2 stops being the right topology.**

At INT4 the model is ~35 GB - it fits comfortably on **one** A100. So the
alternative is two independent single-GPU replicas behind a load balancer:

| | TP=2 | 2× DP replicas |
|---|---|---|
| Cross-GPU traffic per token | ~160 all-reduces | **zero** |
| Latency for a single request | Lower (2 GPUs of compute) | Higher |
| Aggregate throughput | Interconnect-limited | **Near-linear scaling** |
| Max model size | 160 GB | 80 GB |

**Tensor parallelism buys lower single-request latency at the price of constant
synchronisation. That price is only worth paying when the interconnect is fast,
or when the model genuinely does not fit on one device.** With NVLink, TP=2 is
justified. Without it - and with a model that fits after quantization - data
parallelism wins on both throughput and cost.

---

## 6 · Final recommended configuration

`[Name it - probably awq-tuned or awq-prefix.]`

```
--model <INT4 AWQ 70B>
--tensor-parallel-size 2
--max-model-len 8192
--gpu-memory-utilization 0.95
--enable-chunked-prefill
--enable-prefix-caching
--max-num-seqs <tuned>
--max-num-batched-tokens <tuned>
```

**Optimised for:** many concurrent users, short-to-moderate prompts, moderate
output lengths, with a **p99 TTFT** target rather than a raw-throughput target.
Chunked prefill and prefix caching are both latency-oriented choices; the
quantization is what makes the concurrency possible at all.

**When I would configure it differently:**

| Workload | Change |
|---|---|
| Long-context (32K+) | Raise `max-model-len`, accept lower concurrency - it is a direct trade against KV |
| Batch/offline, no latency SLO | Raise `max-num-seqs` hard, drop chunked prefill, optimise pure throughput |
| Strict quality bar | Re-evaluate INT4 - quantization is not free, and this exercise measured speed, not accuracy |
| No NVLink | Two DP replicas at INT4 on one GPU each, not TP=2 |

> **One limitation I would state to a customer:** this exercise optimised
> throughput and latency and did **not** measure output quality. INT4 AWQ is the
> single biggest lever here, and it is also the only change that can alter what
> the model says. Before recommending it in production I would want a quality
> evaluation on the customer's own prompts alongside these numbers.
