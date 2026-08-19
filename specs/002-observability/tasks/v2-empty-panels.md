# v2 - three separate causes of empty panels

**Changes from [v1](v1-metric-renames.md)**

Four panels were blank: KV cache utilisation, TPOT, NVLink traffic, and
tensor-pipe activity. They had **three unrelated causes**, and fixing the first
two did not reveal the third until each was checked against Prometheus directly.

---

## Cause 1 - `make sync` was deleting the scrape target

```
observability/targets/vllm.json  ->  []
```

`scripts/run.sh` writes this file before each level to stamp the `level` label.
`make sync` uses `rsync --delete`, so **every sync overwrote it with the empty
committed version** - silently ending vLLM scraping until the next benchmark run
happened to rewrite it.

Prometheus could reach `vllm:8000` the whole time. It simply had no target.

**Fix:** `--exclude observability/targets` in the rsync invocation.

**Generalisable:** a directory holding *runtime state* must never be inside the
path a deploy tool mirrors. This one looked like configuration because it holds
a JSON file checked into git.

---

## Cause 2 - metric renames

Covered in [v1](v1-metric-renames.md): `gpu_cache_usage_perc` →
`kv_cache_usage_perc`, `time_per_output_token_seconds` →
`inter_token_latency_seconds`.

---

## Cause 3 - dcgm-exporter omits profiling counters by default

`DCGM_FI_PROF_NVLINK_TX_BYTES` had **never** existed - not renamed, not scraped
wrong, simply not exported. The image's default counter list excludes the
`DCGM_FI_PROF_*` family, so the NVLink panel could never have worked.

**Fix:** an explicit counter set at `observability/dcgm-counters.csv`, passed
with `-f`.

### A format constraint worth documenting

The counter file is parsed as strict CSV, so a **comma inside a help string**
silently becomes a fourth field:

```
DCGM_FI_DEV_GPU_UTIL, gauge, GPU utilization (%) - kernel resident, NOT productivity
                                                                 ^ fourth field
```

dcgm-exporter then refuses to start entirely - `record on line 11: wrong number
of fields` - taking down every metric it was already exporting. The file carries
a warning at the top, and the format is validated before shipping:

```bash
python3 -c "import csv;rows=[r for r in csv.reader(open('observability/dcgm-counters.csv')) \
  if r and not r[0].lstrip().startswith('#')];print([i for i,r in enumerate(rows) if len(r)!=3] or 'ok')"
```

---

## Verified

| Metric | Series |
|---|---|
| `vllm:kv_cache_usage_perc` | 1 |
| `vllm:inter_token_latency_seconds_bucket` | 20 |
| `DCGM_FI_PROF_NVLINK_TX_BYTES` | 2 |
| `DCGM_FI_PROF_PIPE_TENSOR_ACTIVE` | 2 |
| `DCGM_FI_PROF_DRAM_ACTIVE` | 2 |

## Operational note

**An empty panel is not one bug.** Three independent failures produced identical
symptoms - no target, wrong name, metric never exported - and none of them raised
an error anywhere. The only reliable diagnosis is querying Prometheus for the
series and working backwards:

```bash
curl -s localhost:9090/api/v1/query?query=count(METRIC)
curl -s localhost:9090/api/v1/targets
```
