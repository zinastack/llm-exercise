# v0 - initial stack


> **Paths in this file are as they were at v0.** `docker-compose.yml` moved to
> the repository root and the scripts to `scripts/` in
> [v4](v4-layout.md).

**When:** first bring-up · **Location:** `observability/docker-compose.yml`

## What it contained

| Service | Purpose |
|---|---|
| `prometheus` | 5s scrape, file-based service discovery |
| `grafana` | dashboards provisioned from code |
| `dcgm-exporter` | GPU telemetry |
| `cloudflared` | public exposure, outbound-only |

vLLM is deliberately **not** in compose - each benchmark level starts and stops
its own server so the configuration under test is unambiguous.

## Design decisions

**File-based service discovery, not a static target.** `run.sh` rewrites
`observability/targets/vllm.json` before each level, stamping
`level="fp16-L2-kv"` onto every scraped series. That single label is what lets
one Grafana panel compare baseline against every iteration, instead of four
dashboards to flip between.

**Compose, not Kubernetes.** Single node, short-lived. Compose is up in seconds
with no control plane. Kubernetes would buy scheduling, self-healing and
multi-node placement - none of it needed here.

## Problems found

- `shm_size` at Docker's 64 MB default **deadlocks tensor parallel** with no
  error message. Set to 16 GB.
- Grafana root URL was derived from `DOMAIN`, which broke as soon as a hostname
  collided in DNS.
