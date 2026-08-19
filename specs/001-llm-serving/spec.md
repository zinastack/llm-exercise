# 001 - LLM serving on 2× NVLink-connected A100s

**Status:** in progress · **Owner:** Lacina · **Created:** 2026-08-18

## Problem

From the brief, quoted rather than paraphrased:

> Deploy an open-weight large language model across two NVIDIA A100 GPUs
> connected via NVLink, first with standard/default deployment settings, then
> iteratively improve the deployment configuration to achieve better **output
> token throughput** and better **time-to-first-token (TTFT)** under concurrent
> load.
>
> This exercise is about serving and deployment engineering - **you will not be
> training or modifying model weights.**

## Constraints

| | |
|---|---|
| Hardware | 2× A100-SXM4-80GB, NVLink `NV12` (600 GB/s bidirectional) |
| Total HBM | 160 GB |
| Compute capability | **8.0 - no native FP8** |
| Model | 70B-class open weight |
| Host | Rented and ephemeral; local NVMe is wiped on teardown |

**The arithmetic that defines the problem:**

```
Llama-3.1-70B at FP16   ~141 GB weights
2 × A100 80GB            160 GB HBM
                         ─────────────
KV cache headroom         ~19 GB  ≈ 59,000 tokens
```

Every improvement is a fight for KV headroom, because headroom sets batch size
and batch size sets throughput.

## Out of scope

- **Training, fine-tuning, or modifying weights.** Stated explicitly in the brief.
- **Re-quantizing a model.** Serving a *published* quantized checkpoint is a
  deployment decision and is reported as a labelled comparison, not as a tuning
  level. See "Decisions" below.
- **Output quality evaluation.** Not measured. Recorded as an honest gap because
  quantization is the only change that can alter what the model says.

## Success criteria

1. A baseline exists at vLLM defaults, benchmarked at ≥2 concurrency levels,
   reporting output token throughput, **TTFT including tail percentiles**, and
   any errors, timeouts or degraded behaviour.
2. Each subsequent change is re-benchmarked under **identical** conditions.
3. At the heaviest concurrency level, at least one configuration demonstrably
   improves throughput **and** TTFT versus baseline.
4. The NVLink question is answered with a **measurement**, not an assertion.
5. Every number in every document traces to a file in `bench/out/`.

## Decisions

**D1 - Model: Llama-3.1-70B-Instruct.** The canonical reading of "70B-class",
and the model most serving figures are published against, so results are
comparable to numbers a reader already has intuitions about.

**D2 - Quantization is not a tuning level.** *Corrected by the human against the
AI's initial proposal.* The first design made INT4 AWQ a core level, which drifts
from "you will not be modifying model weights". It was rebuilt as
configuration-only levels, with quantization reported separately and its caveat
attached. Recorded here because the correction is part of the engineering record.

**D3 - Concurrency 256 added rather than replacing the workload.** The first
round showed only 3% improvement: at 768-token requests against a 347K-token
cache, KV was never the binding constraint. Adding a third concurrency level
preserves comparability with existing results while creating a genuinely
constrained regime.

## Resolved during scoping

**Is FP16 required?** No. The brief specifies "70B-class" and "default settings",
never a dtype.

**Does INT4 degrade output quality for this workload?** Out of scope, and stated
as such in the report. This exercise measures serving performance; quantization
is the one change that can alter what the model says, so a quality evaluation on
real prompts belongs beside these numbers before any production recommendation.
