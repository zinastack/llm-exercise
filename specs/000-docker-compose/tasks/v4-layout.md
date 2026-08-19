# v4 - repository layout and the operational interface

**Changes from [v3](v3-chat-proxy.md)**

> This file describes a move, so it names **both** the old and new paths
> deliberately. Old paths here are historical and no longer resolve.


## Problem

Shell scripts and reference documents had accumulated at the repository root:
`ANALYSIS.md`, plus a `cloudflared/` directory holding one reference file. The
root is what someone reads first, and it had stopped saying what the project is.

## Change

| Moved | To |
|---|---|
| `configs.sh`, `run.sh`, `stack.sh` | `scripts/` - alongside `setup-node.sh` |
| `cloudflared/config.yml` | `observability/cloudflared-config.yml` |

`docker-compose.yml`, `Makefile`, `README.md`, `REPORT.md` and `RESULTS.md` stay
at the root: they are what the project *is*, not supporting detail.

Scripts had to be adjusted - `cd "$(dirname "$0")/.."` and
`source ./scripts/configs.sh` - and every `Makefile` reference rewritten.
Verified by running `scripts/stack.sh` on the remote host after the move.

## Makefile targets added along the way

| Target | Purpose |
|---|---|
| `doctor` | Instance state, SSH, GPUs, docker+nvidia, disk, startup log - **run before trusting the box** |
| `remote CMD='...'` | Drive the host without an interactive shell, after `brev exec` proved unreliable |
| `weights` | Fetch both checkpoints with `hf_transfer` |
| `webui-admin` | Create the first Open WebUI account, then close signup |
| `archive` | Pull Prometheus, Grafana and results down **before** teardown |
| `capacity` | Instance availability **and disk range** - a type that cannot hold the weights is not a candidate |

