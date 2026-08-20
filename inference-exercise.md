# LLM Serving on 2× NVLink-Connected A100s

## Overview

You'll deploy an open-weight large language model across two NVIDIA A100 GPUs connected via NVLink, first with standard/default deployment settings, then iteratively improve the deployment configuration to achieve better **output token throughput** and better **time-to-first-token (TTFT)** under concurrent load.

This exercise is about serving and deployment engineering — you will not be training or modifying model weights.


## Hardware

- 2× NVIDIA A100 GPUs
- NVLink interconnect between the two GPUs 

## Part 1 — Baseline Deployment

Deploy a large open-weight model (70B-class) across both GPUs using standard, default deployment settings. Confirm the deployment is serving requests correctly.

Benchmark this baseline deployment under at least two levels of concurrent request load (a light load and a heavier load), and record:

- Output token throughput
- Time-to-first-token (TTFT), including tail latency (not just the average)
- Any errors, timeouts, or degraded behavior under the heavier load

This baseline is what you'll compare all further work against.

## Part 2 — Improve Throughput and TTFT

Your goal: improve output token throughput and improve TTFT at the heavier concurrency level, compared to your Part 1 baseline.

For each meaningful change you make, re-benchmark under the same conditions as your baseline so your results are directly comparable.


## Deliverables

1. A description of your baseline deployment and the exact configuration used.
2. A results table comparing your baseline against each iteration you tried: throughput and TTFT (including tail percentiles) at both concurrency levels.
3. A written analysis covering:
   - What had the biggest impact on throughput, and why you believe that
   - What had the biggest impact on TTFT, and why
   - Any case where a change improved one metric while hurting the other, and how you reasoned about that trade-off
   - Explain how does the NVLink connection between these two GPUs specifically matter to this deployment, and what would you expect to change if it weren't there?
   - Your final recommended configuration, and what kind of workload it's optimized for
4. Enough detail (commands, scripts, or configuration files you used)

