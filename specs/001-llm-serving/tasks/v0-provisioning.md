# 001 · v0 - Provisioning and validation

Bring-up on rented hardware, with each gate recording what it found. Gates exist
to surface environment differences before the long-running work depends on them,
so a gate that fires has done its job.

---

## Phase 0 - De-risk before the long-running work

Ordered so the fastest check capable of invalidating the rest runs first.

- [x] **`make capacity` - disk range, not just availability.**
      One candidate instance type has its disk fixed at 128 GB against ~141 GB of
      FP16 weights - it cannot hold the model at all, so nothing else about it
      matters. Selected GCP `a2-ultragpu-2g`, where disk is configurable. The
      target now reports disk range alongside availability so the disqualifying
      constraint is visible first.

- [x] **`make provision`** - 2× A100-SXM4-80GB.

- [x] **`make doctor` - connectivity proven before anything depends on it.**
      `brev exec` returns SSH 255 on this provider. Brev's generated SSH config
      works, so `sync`/`doctor`/`remote`/`shell` were rewired onto `ssh` and
      `rsync` directly. The provider's own CLI is now a dependency only for
      create and delete.

- [x] **Storage sized for the workload.**
      `--min-disk` on the provisioner filters instance *types*; it does not
      request a disk size, so the boot volume arrived at 125 GB. The instance
      class ships two unmounted 375 GB local NVMe devices - one is now formatted
      and mounted at `/mnt/models` by `scripts/setup-node.sh`, and the HF cache
      points there. Local SSD is ephemeral, which is why `make archive` exists.

- [x] **`make topo` - `NV12` confirmed.**
      12 NVLink 3.0 links, 600 GB/s bidirectional. The exercise premise depends
      on this, so it is verified before anything else runs.

- [x] **`make smoke` - the flag surface validated against the pinned image.**
      A 1.5 B model exercises the full path - tensor parallelism, metric
      labelling, dashboards, benchmark harness - in minutes rather than hours.
      It surfaced that `--disable-log-requests` no longer exists in this release
      (inverted to `--enable-log-requests`, default off). All thirteen flags were
      then checked against `--help=all` in one pass rather than discovered one
      failure at a time, and the image pinned by digest so the flag surface
      cannot move underneath the results.

- [x] **Captured metrics reconciled against the brief** - throughput, TTFT
      including tails, and errors/timeouts.

> **What Phase 0 established:** three environment differences - provider SSH
> behaviour, disk provisioning semantics, and a changed vLLM flag surface - all
> surfaced at small scale, before a 141 GB download and the full benchmark
> sequence depended on any of them.

---

## Access

- [x] **Gated model access resolved.**
      Licence approval and *token scope* are separate grants on Hugging Face:
      repo metadata returned `200` while file content returned `403`. The
      fine-grained token was scoped to `meta-llama/Meta-Llama-3-8B` rather than
      the target repository. Re-scoped, verified by fetching `config.json`
      before starting the download rather than discovering it mid-transfer.

- [x] **`hf_transfer` enabled** - 141 GB fetched in minutes rather than the hour
      the default client would take. Note `hf download` treats trailing
      positional arguments as *files to fetch*, so `--exclude` takes one pattern
      per flag; the transfer is size-verified rather than trusting exit status.

---

## Phase 1–2 - Baseline and levels

- [x] INT4 progression at c=4 / c=64
- [x] **Finding: 3% improvement across every level.** At 768-token requests
      against a 347,000-token cache the system was never KV-bound, so
      KV-oriented levers had nothing to act on. Diagnosed by pairing cache
      utilisation with the preemption counter - low and zero respectively.
      **Response: add concurrency 256** rather than alter the workload, so
      earlier results stay comparable.
- [x] **`fp16-baseline` does not start** - 128K default context cannot be
      reserved in ~19 GB of KV. Recorded as a result. *This is the Part 1
      answer.*
- [x] `baseline-servable` - the single minimal change required to serve, as the
      reference point for Part 2
- [x] `fp16-L1-fit`, `fp16-L2-kv`, `fp16-L3-schedule` at c=4 / 64 / 256

## Phase 3–4 - Control and comparison

- [x] `nvlink-off` (INT4) - −20.5% throughput, +84% TTFT p99 at c=64; negligible
      at c=4
- [x] `fp16-nvlink-off` - −37% throughput at c=256
- [x] Quantization comparison folded into `REPORT.md` §5

## Phase 5 - Deliverables

- [x] `make archive` - Prometheus TSDB, Grafana state and every result pulled
      down before teardown
- [x] `REPORT.md`, `docs/DELIVERABLES.md` complete, generated from `bench/out/`
- [ ] `make destroy` - **human only**, and after `make archive`
