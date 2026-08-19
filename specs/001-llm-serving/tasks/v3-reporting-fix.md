# v3 - a false statement in the report generator

**Changes from [v2](v2-fp16-benchmark.md)**

## The bug

`bench/report.py` printed **"all failed"** for every INT4 configuration at
concurrency 256:

```
| `baseline`     | **all failed** | - | - |
| `L2-kv`        | **all failed** | - | - |
```

They did not fail. **They were never run at that concurrency** - the INT4 rounds
predate concurrency 256 being added to the workload. The generator treated a
missing measurement as a failed one.

## Why it mattered

Reviewing generated output against the run log is what surfaced this: the report
asserted a failure that the run history did not contain. Left in place, the
deliverable would have carried a **false claim about its own results** - the kind
that survives review precisely because it looks like a legitimate negative
result.

## Change

Three distinct states, never conflated:

| State | Rendered as |
|---|---|
| Not measured at this concurrency | *not run at this level* |
| Engine refused to start | **engine refused to start** |
| Ran, every request failed | **all requests failed** + reasons |

`RESULTS.md` also now states up front that two model families are reported and
why the INT4 rows are absent at concurrency 256, so the gap is explained rather
than left to be inferred.

## Operational note

**Absent data and failed data are different claims.** Any generator that cannot
distinguish them will eventually assert the wrong one - in a document read as
fact. Worth encoding in the generator rather than trusting review to catch it
every time.
