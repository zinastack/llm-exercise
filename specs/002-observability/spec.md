# 002 - Observability

**Status:** done

## Problem

Benchmark numbers say *what* happened. They do not say *why*. A throughput figure
without KV cache utilisation, preemption counts and GPU tensor-pipe activity
beside it cannot be explained, only reported.

Every tuning level must be comparable to every other **on the same panel**, and
the data must survive teardown of an ephemeral instance.

## Success criteria

1. Serving metrics and GPU telemetry scraped for every level.
2. All levels comparable on shared panels, not separate dashboards.
3. Dashboards defined as code, not clicked together.
4. Full history recoverable after the hardware is destroyed.

## Out of scope

Alerting, long-term retention, multi-tenant access.
