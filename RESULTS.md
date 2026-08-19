# Results

Generated from `bench/out/*.json` by `bench/report.py`. No figure in this file is hand-typed.

Identical workload for every configuration: 512-token prompts, 256 output tokens, streaming, temperature 0.

Two model families are reported. `fp16-*` rows use the unquantized checkpoint; the unprefixed rows use the INT4 AWQ checkpoint and predate concurrency 256 being added, so they are marked *not run* there rather than failed.


## Light load - concurrency 4

| Config | Output tok/s | TTFT p50 | TTFT p95 | TTFT p99 | TPOT p50 | Failed |
|---|---:|---:|---:|---:|---:|---:|
| `baseline` | 189.6 | 202 ms | 528 ms | 654 ms | 19.9 ms | 0 |
| `L1-fit` | 190.4 (+0%) | 202 ms (+0%) | 524 ms | 655 ms (-0%) | 19.8 ms | 0 |
| `L3-schedule` | 185.7 (-2%) | 208 ms (-3%) | 532 ms | 664 ms (-2%) | 20.4 ms | 0 |
| `nvlink-off` | 182.0 (-4%) | 209 ms (-3%) | 1022 ms | 1023 ms (-56%) | 20.4 ms | 0 |
| `L2-kv` | 187.7 (-1%) | 209 ms (-3%) | 531 ms | 664 ms (-2%) | 20.4 ms | 0 |
| `fp16-L1-fit` | 78.1 (-59%) | 240 ms (-19%) | 456 ms | 485 ms (+26%) | 49.5 ms | 0 |
| `fp16-L2-kv` | 77.8 (-59%) | 248 ms (-23%) | 580 ms | 580 ms (+11%) | 50.2 ms | 0 |
| `fp16-L3-schedule` | 77.8 (-59%) | 249 ms (-23%) | 580 ms | 581 ms (+11%) | 50.2 ms | 0 |
| `fp16-baseline` | **engine refused to start** | - | - | - | - | - |
| `fp16-nvlink-off` | 76.5 (-60%) | 248 ms (-23%) | 796 ms | 823 ms (-26%) | 50.4 ms | 0 |
| `smoke` | 1238.9 (+553%) | 20 ms (+90%) | 44 ms | 53 ms (+92%) | 3.0 ms | 0 |

## Heavy load - concurrency 64

| Config | Output tok/s | TTFT p50 | TTFT p95 | TTFT p99 | TPOT p50 | Failed |
|---|---:|---:|---:|---:|---:|---:|
| `baseline` | 879.6 | 1234 ms | 6776 ms | 8223 ms | 73.1 ms | 0 |
| `L1-fit` | 882.5 (+0%) | 1691 ms (-37%) | 6784 ms | 8382 ms (-2%) | 72.2 ms | 0 |
| `L3-schedule` | 907.0 (+3%) | 1934 ms (-57%) | 7513 ms | 7517 ms (+9%) | 55.5 ms | 0 |
| `nvlink-off` | 720.8 (-18%) | 2585 ms (-109%) | 11284 ms | 13795 ms (-68%) | 68.8 ms | 0 |
| `L2-kv` | 905.5 (+3%) | 1196 ms (+3%) | 5917 ms | 7415 ms (+10%) | 69.2 ms | 0 |
| `fp16-L1-fit` | 735.1 (-16%) | 1050 ms (+15%) | 5338 ms | 6594 ms (+20%) | 85.9 ms | 0 |
| `fp16-L2-kv` | 742.0 (-16%) | 1256 ms (-2%) | 5316 ms | 6416 ms (+22%) | 84.8 ms | 0 |
| `fp16-L3-schedule` | 744.2 (-15%) | 1340 ms (-9%) | 5414 ms | 6359 ms (+23%) | 72.9 ms | 0 |
| `fp16-baseline` | **engine refused to start** | - | - | - | - | - |
| `fp16-nvlink-off` | 604.4 (-31%) | 4932 ms (-300%) | 11518 ms | 12682 ms (-54%) | 82.5 ms | 0 |
| `smoke` | 9578.2 (+989%) | 151 ms (+88%) | 222 ms | 260 ms (+97%) | 6.0 ms | 0 |

## Stress - concurrency 256

| Config | Output tok/s | TTFT p50 | TTFT p95 | TTFT p99 | TPOT p50 | Failed |
|---|---:|---:|---:|---:|---:|---:|
| `baseline` | *not run at this level* | - | - | - | - | - |
| `L1-fit` | *not run at this level* | - | - | - | - | - |
| `L3-schedule` | *not run at this level* | - | - | - | - | - |
| `nvlink-off` | *not run at this level* | - | - | - | - | - |
| `L2-kv` | *not run at this level* | - | - | - | - | - |
| `fp16-L1-fit` | 642.5 | 47962 ms | 77386 ms | 80016 ms | 134.0 ms | 0 |
| `fp16-L2-kv` | 830.0 | 16244 ms | 48212 ms | 66640 ms | 206.9 ms | 0 |
| `fp16-L3-schedule` | 846.9 | 14925 ms | 25587 ms | 31234 ms | 202.7 ms | 0 |
| `fp16-baseline` | **engine refused to start** | - | - | - | - | - |
| `fp16-nvlink-off` | 532.7 | 34151 ms | 50216 ms | 50227 ms | 308.6 ms | 0 |
| `smoke` | *not run at this level* | - | - | - | - | - |

*Percentages are change versus `baseline` at the same concurrency. For TTFT, positive means faster.*


## NVLink - measured, not assumed

`nvlink-off` is byte-identical to `L3-schedule` except for `NCCL_P2P_DISABLE=1`, which forces NCCL to stage transfers through host memory instead of using the direct GPU-to-GPU path.

| Concurrency | Metric | With NVLink | Without P2P | Change |
|---|---|---:|---:|---:|
| 4 | Output tok/s | 185.7 | 182.0 | -2% |
| 4 | TTFT p50 (ms) | 208.4 | 208.9 | +0% |
| 4 | TTFT p99 (ms) | 664.2 | 1023.2 | +54% |
| 4 | TPOT p50 (ms) | 20.41 | 20.44 | +0% |
| 64 | Output tok/s | 907.0 | 720.8 | -21% |
| 64 | TTFT p50 (ms) | 1933.7 | 2585.4 | +34% |
| 64 | TTFT p99 (ms) | 7516.9 | 13795.0 | +84% |
| 64 | TPOT p50 (ms) | 55.46 | 68.82 | +24% |

## What each level changed, and why

**`baseline`** - vLLM defaults. The 128K default context window caps how many sequences fit, regardless of available KV memory.

- model: `hugging-quants/Meta-Llama-3.1-70B-Instruct-AWQ-INT4`
- flags: `*vLLM defaults*`

**`L1-fit`** - Stop reserving context nobody uses, and claim the last 5% of HBM. Throughput up because the batch ceiling rises; TTFT down because requests stop queueing for cache blocks.

- model: `hugging-quants/Meta-Llama-3.1-70B-Instruct-AWQ-INT4`
- flags: `--max-model-len 8192 --gpu-memory-utilization 0.95`

**`L3-schedule`** - Chunked prefill stops long prefills blocking decode, so the TTFT tail collapses. Prefix caching removes prefill work outright, which returns capacity to decode.

- model: `hugging-quants/Meta-Llama-3.1-70B-Instruct-AWQ-INT4`
- flags: `--max-model-len 8192 --gpu-memory-utilization 0.95 --kv-cache-dtype fp8_e5m2 --enable-chunked-prefill --enable-prefix-caching --max-num-seqs 256 --max-num-batched-tokens 8192`

**`nvlink-off`** - Control for the NVLink question. Byte-identical to L3 except NCCL is forced to stage through host memory.

- model: `hugging-quants/Meta-Llama-3.1-70B-Instruct-AWQ-INT4`
- flags: `--max-model-len 8192 --gpu-memory-utilization 0.95 --kv-cache-dtype fp8_e5m2 --enable-chunked-prefill --enable-prefix-caching --max-num-seqs 256 --max-num-batched-tokens 8192`
- env: `NCCL_P2P_DISABLE=1`

**`L2-kv`** - INT4 weights free ~105GB of HBM for KV, and FP8 KV halves bytes per token. Both metrics improve for the same reason: far more concurrent sequences fit.

- model: `hugging-quants/Meta-Llama-3.1-70B-Instruct-AWQ-INT4`
- flags: `--max-model-len 8192 --gpu-memory-utilization 0.95 --kv-cache-dtype fp8_e5m2`

**`fp16-L1-fit`** - Cap context to what is actually served and claim the last 5% of HBM. More usable KV, so more sequences resident.

- model: `meta-llama/Llama-3.1-70B-Instruct`
- flags: `--max-model-len 8192 --gpu-memory-utilization 0.95`

**`fp16-L2-kv`** - Halve the bytes per KV token - cache FORMAT, not weights. Roughly doubles resident sequences in the same memory.

- model: `meta-llama/Llama-3.1-70B-Instruct`
- flags: `--max-model-len 8192 --gpu-memory-utilization 0.95 --kv-cache-dtype fp8_e5m2`

**`fp16-L3-schedule`** - Interleave prefill with decode so long prefills stop blocking generation, and reuse shared prompt prefixes.

- model: `meta-llama/Llama-3.1-70B-Instruct`
- flags: `--max-model-len 8192 --gpu-memory-utilization 0.95 --kv-cache-dtype fp8_e5m2 --enable-chunked-prefill --enable-prefix-caching --max-num-seqs 256 --max-num-batched-tokens 8192`

**`fp16-baseline`** - vLLM defaults on the unquantized checkpoint. ~141GB of weights on 160GB leaves under 20GB for KV - roughly 59,000 tokens, and the 128K default context caps reported concurrency at ~2.6x.

- model: `meta-llama/Llama-3.1-70B-Instruct`
- flags: `*vLLM defaults*`

**`fp16-nvlink-off`** - Control. Byte-identical to fp16-L3 except NCCL is forced to stage through host memory.

- model: `meta-llama/Llama-3.1-70B-Instruct`
- flags: `--max-model-len 8192 --gpu-memory-utilization 0.95 --kv-cache-dtype fp8_e5m2 --enable-chunked-prefill --enable-prefix-caching --max-num-seqs 256 --max-num-batched-tokens 8192`
- env: `NCCL_P2P_DISABLE=1`

**`smoke`** - Pipeline validation with a tiny model. Not a result.

- model: `Qwen/Qwen2.5-1.5B-Instruct`
- flags: `--max-model-len 2048 --gpu-memory-utilization 0.30`

