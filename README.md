# LLM Serving on 2× NVLink-Connected A100s

Benchmark Llama-3.1-70B-Instruct on 2× A100 80GB with NVLink, then improve output
token throughput and TTFT through deployment configuration alone.

> **Evaluating this? Read [`REPORT.md`](REPORT.md) first** - it is the
> deliverable: measurements, analysis, and recommendation.
> **This file is the runbook**: how to reproduce it on your own hardware.

| Document | Read it for |
|---|---|
| [**`REPORT.md`**](REPORT.md) | **The deliverable.** What was measured and what it means |
| [`RESULTS.md`](RESULTS.md) | Generated results table - every level, every concurrency |
| **This file** | How to run it yourself |
| [`docs/DELIVERABLES.md`](docs/DELIVERABLES.md) | Each exercise requirement mapped to where it is answered |
| [`specs/`](specs/) | What was asked, how it was planned, what actually happened |
| [`ai-usage.md`](ai-usage.md) | How AI was used and the guardrails it ran under |

---

## Where things live

Two questions this layout raises, answered up front.

### vLLM is not in `docker-compose.yml` - deliberately

The compose file holds only the **persistent** stack: Prometheus, Grafana, DCGM,
the chat UI and its proxy. Those stay up across every benchmark.

**vLLM is started and stopped per benchmark level by
[`scripts/run.sh`](scripts/run.sh)**, using flags from
[`scripts/configs.sh`](scripts/configs.sh) - one entry per level, each with a
one-line rationale.

If vLLM lived in compose it would persist across levels, and it would stop being
unambiguous which configuration produced which numbers. Each measurement runs
against exactly one known set of flags, and the flags are recorded *inside* the
result file alongside the numbers.

```bash
grep -A3 'L2-kv' scripts/configs.sh     # the flags and why
jq '.flags' bench/out/fp16-L2-kv.json   # the flags that produced these numbers
```

### `archive/` exists because the GPU host is disposable

The instance runs on ephemeral local NVMe - teardown wipes it, and the Prometheus
history would go with it. `make archive` pulls the time-series database and every
result JSON down before that happens.

**The time-series is committed** (322 KB), so anyone cloning this repository can
replay the real runs:

```bash
cd archive && mkdir -p prom-data && tar xzf prometheus-data.tgz -C prom-data
docker compose up -d                    # Grafana on :3000, every level intact
```

`bench/out/*.json` gives the per-level aggregates; this gives the **timeline** -
KV cache filling, preemptions starting, NVLink traffic against wall clock. It is
why the GPU host can be destroyed the moment the runs finish.

---

## Requirements

- A host with **2× A100 80GB connected by NVLink** (SXM4 - verify below)
- **≥ 210 GB of free disk** for model weights
- Docker with the NVIDIA container runtime
- A Hugging Face token with access to `meta-llama/Llama-3.1-70B-Instruct`

> **Why docker compose and not Kubernetes:** this is a single-node, short-lived
> benchmark rig. Compose brings the whole stack up in seconds with no control
> plane to install or maintain. Kubernetes would add scheduling, self-healing and
> multi-node placement - none of which a single-node benchmark needs, all of
> which add moving parts between the measurement and the hardware. The right tool
> for the size of the problem.

---

## 1 · Verify the hardware

```bash
make topo
```

Expect `NV12` between GPU0 and GPU1 - twelve NVLink 3.0 links, 600 GB/s
bidirectional:

```
       GPU0    GPU1
GPU0     X     NV12
GPU1   NV12      X
```

**Anything else - `PIX`, `PXB`, `PHB`, `SYS` - means there is no NVLink**, and the
premise of the exercise does not hold on that machine.

---

## 2 · Configure

```bash
cp .env.example .env
```

Fill in:

```bash
HF_TOKEN=hf_...                    # needs gated-repo content access, see below
API_KEY=$(openssl rand -hex 24)    # protects the inference endpoint
GRAFANA_PASSWORD=$(openssl rand -hex 12)
HF_CACHE=/mnt/models/huggingface   # must be on a disk with ≥210 GB free
```

> **Hugging Face gotcha.** A *fine-grained* token does **not** inherit gated-model
> access from your account - licence approval alone is not enough. Either tick
> **"Read access to contents of all public gated repos you can access"** on the
> token, or use a classic **Read** token. Symptom if you miss it: repo metadata
> returns `200` while file content returns `403`.

The vLLM image is **pinned by digest** in `.env.example`. Leave it pinned -
`latest` would silently change the thing being measured.

---

## 3 · Fetch the weights

```bash
make weights
```

Downloads 141 GB (FP16) and 39.8 GB (INT4 AWQ). Uses `hf_transfer`, which is
several times faster than the default client.

---

## 4 · Start the stack

```bash
make stack
```

Brings up Prometheus, Grafana, the DCGM exporter and the chat UI, and **leaves
them running across every benchmark**. Grafana is on `http://localhost:3000`.

vLLM itself is *not* started here - each benchmark level starts and stops its own
server so the configuration under test is unambiguous.

---

## 5 · Validate at small scale first

```bash
make smoke
```

Runs a 1.5B model through the entire pipeline in a few minutes. If it produces
numbers, then tensor parallelism, the metrics labelling, Grafana and the
benchmark harness are all working.

**Do this first.** On the reference run it caught three failures that would
otherwise have surfaced only after a 141 GB download.

---

## 6 · Run the benchmarks

Everything at once:

```bash
make levels      # baseline → L1-fit → L2-kv → L3-schedule
make nvlink      # the NVLink control run
make report      # → RESULTS.md
```

Or one at a time:

```bash
make one LEVEL=baseline
make one LEVEL=fp16-L2-kv
```

**`make levels` runs the reported progression, all on the FP16 checkpoint:**

| Level | Change | Mechanism |
|---|---|---|
| `fp16-baseline` | vLLM defaults | **Refuses to start** - 128K context needs 19 GB of KV, 7.4 GB available. This is the Part 1 result |
| `baseline-servable` | `--max-model-len 8192` | The single minimal change required to serve. Everything else default. **All improvements are measured against this** |
| `fp16-L1-fit` | `+ --gpu-memory-utilization 0.95` | Claim the HBM vLLM leaves free |
| `fp16-L2-kv` | `+ --kv-cache-dtype fp8_e5m2` | Halve bytes per KV token - cache format, not weights |
| `fp16-L3-schedule` | `+ chunked prefill, prefix caching, max-num-seqs` | Stop prefill blocking decode |

Two more, run separately:

| Target | Runs | Purpose |
|---|---|---|
| `make nvlink` | `fp16-nvlink-off` | Control - identical to L3 with `NCCL_P2P_DISABLE=1` |
| `make int4` | `baseline`, `L1-fit`, `L2-kv`, `L3-schedule` | Same progression on the INT4 AWQ checkpoint, for the quantization comparison |

Every level uses **identical** conditions: 512-token prompts, 256-token outputs,
streaming, temperature 0, concurrency **4 / 64 / 256**. Enforced in `scripts/run.sh`, not
by convention - a comparison is only valid if one thing changed.

`make report` regenerates `RESULTS.md` from `bench/out/*.json`. **No number is
ever typed by hand** - and both are committed, so every figure in the report has
its source in the repository.

---

## 7 · Read the results

**`RESULTS.md`** - throughput, TTFT p50/p95/p99, TPOT and failure counts per
level, at each concurrency, with deltas against baseline.

**Grafana** at `http://localhost:3000` - every level is labelled, so baseline and
each iteration appear on the same panels rather than in separate dashboards.

The panels that explain the numbers:

| Panel | Tells you |
|---|---|
| KV cache utilisation | Whether the batch ceiling is KV-bound |
| Preemptions | Whether the engine is admitting more than it can hold |
| Running vs waiting | Queue depth - the direct cause of a bad TTFT tail |
| **Tensor-pipe active vs GPU util** | Whether the GPU is *busy* or *productive* |
| NVLink traffic | Drops to ~zero on the control run |

**`GPU_UTIL` only means a kernel was resident.** Decode is memory-bandwidth-bound,
so high utilisation with low tensor-pipe activity is expected here - not a fault.
Mistaking one for the other sends you optimising the wrong thing.

Per-level, `bench/out/<level>.startup.txt` holds vLLM's own **KV cache size** and
**maximum concurrency** - the most informative output of the whole exercise.

---

## 8 · Preserve the results

```bash
make archive
```

Copies the Prometheus database, Grafana state and every result JSON into
`archive/`. Replay it anywhere afterwards:

```bash
cd archive
mkdir -p prom-data && tar xzf prometheus-data.tgz -C prom-data
docker compose up -d          # Grafana on http://localhost:3000
```

**`prometheus-data.tgz` is committed**, so a clone of this repository can replay
the actual runs - not an empty dashboard. Grafana provisions its datasource and
dashboards from `observability/grafana/`, so no Grafana state is shipped.

**Run this before tearing anything down.** On ephemeral instances the local disk
is wiped on teardown and the measurements go with it.

---

## Layout

```
README.md              this file - how to run it
REPORT.md              the written analysis
RESULTS.md             generated results table (committed)
Makefile               every operation as a named target
docker-compose.yml     the stack - Prometheus, Grafana, DCGM, proxy, chat UI

scripts/
  configs.sh           one entry per level, each with its mechanism
  run.sh               one level: label metrics, serve, benchmark, record
  stack.sh             bring the observability stack up or down
  setup-node.sh        host bring-up, including the local NVMe mount
bench/
  benchmark.py         load generator - TTFT tails, TPOT, throughput, errors
  report.py            bench/out/*.json → RESULTS.md
  out/                 raw measurements (committed - the provenance)
observability/         prometheus config, dashboards as code
proxy/                 strips tool injection from chat UI requests
archive/               offline replay of the recorded metrics
docs/                  Cloudflare setup, deliverables map, analysis
specs/                 what was asked, how it was planned, what happened
```

---

## Troubleshooting

| Symptom | Cause |
|---|---|
| vLLM exits immediately, "max seq len larger than KV cache" | **Expected at baseline.** The default 128K context does not fit. That is the Part 1 finding, not a bug |
| Container hangs at startup with no error | `shm_size` too small - tensor parallel needs shared memory. Set to 16 GB here |
| `403` fetching the model | Fine-grained token without gated-repo content access (see §2) |
| `hf download` reports success with nothing on disk | `--exclude` takes one pattern per flag; trailing positional arguments are read as *files to fetch* |
| Grafana panels empty | Check `docker logs prometheus`; `scripts/run.sh` rewrites `observability/targets/vllm.json` before each level |
