# 001 - Implementation plan

Ordered so that anything capable of invalidating the long-running work executes first.

## Phase 0 - De-risk before the long-running work

| Step | Mechanism | Risk it removes |
|---|---|---|
| `make capacity` | Disk range and availability; weights need ≥205 GB | Provisioning a host that cannot hold the model |
| `make doctor` | SSH, GPUs, docker + nvidia runtime, disk, startup log | Depending on a host that cannot be reached |
| `make topo` | Confirm `NV12` | Building the exercise on a false premise |
| `make smoke` | 1.5 B model through the full pipeline | Flag, permission and plumbing differences surfacing only after a 141 GB download |

## Phase 1 - Baseline

vLLM defaults, TP=2, nothing else. Expected to be **starved**: 128K default
context against ~19 GB of KV. A refusal to start is a valid and informative
result, not a failure to be retried away.

## Phase 2 - Tuning levels, cumulative, configuration only

| Level | Change | Mechanism | Expected signature |
|---|---|---|---|
| `L1-fit` | `max-model-len 8192`, `gpu-mem-util 0.95` | Stop reserving context nobody uses; claim remaining HBM | Cache usage up, preemptions flat |
| `L2-kv` | `kv-cache-dtype fp8_e5m2` | Halve bytes per KV token - cache *format*, not weights | ~2× resident sequences |
| `L3-schedule` | chunked prefill, prefix caching, `max-num-seqs` | Stop prefill blocking decode; skip shared prefixes | **p99 TTFT improves far more than p50** |

If only the mean moves on L3, the mechanism is not the one described - say so.

## Phase 3 - NVLink, measured

`nvlink-off` is byte-identical to L3 except `NCCL_P2P_DISABLE=1`, forcing NCCL
through host memory. TP=2 performs ~160 all-reduces per forward pass across 80
layers, so decode should degrade more than prefill in relative terms.

**Caveat to state:** this is a *lower bound*, not a simulation of PCIe-attached
A100s - it brackets the answer rather than reproducing it.

## Phase 4 - Quantization comparison

Published INT4 AWQ checkpoint, same configuration. Reported as a comparison with
its scope caveat, never as a level.

## Phase 5 - Archive, then teardown

`make archive` first - local NVMe is ephemeral and teardown is irreversible.
`make destroy` is human-only.

