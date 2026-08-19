# 000 - Plan

## Composition

| Service | Role | Lifecycle |
|---|---|---|
| `prometheus` | Scrape vLLM and DCGM every 5s | persistent across levels |
| `grafana` | Dashboards provisioned from code | persistent |
| `dcgm-exporter` | GPU telemetry | persistent |
| `open-webui` | Chat interface | persistent |
| `cloudflared` | Public exposure | persistent, compose profile `public` |
| **`vllm`** | The model server | **started and stopped per benchmark level by `scripts/run.sh`** |

**vLLM is deliberately not in compose.** Each level must run under exactly one
known configuration; leaving the server up across levels would make it ambiguous
which flags produced which numbers.

## Decisions

**Pin the compose project name.** It is otherwise derived from the parent
directory, so moving the file rebinds every named volume and silently orphans
the data. Learned the hard way - see `tasks/v2-docker-compose.md`.

**`shm_size: 16g`.** Docker's 64 MB default deadlocks tensor parallel with no
error message.

**Tunnel behind a profile.** `cloudflared` needs a token; gating it means the
stack still runs for anyone without a Cloudflare account.

## Risk

A container added to the measurement host could perturb results. Mitigated: only
`vllm` holds a GPU, and the rest are idle during benchmarks.
