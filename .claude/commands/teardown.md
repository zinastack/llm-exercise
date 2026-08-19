---
description: Archive all state, then propose destroying the instance
---

**Archiving is not optional.** The instance's local NVMe is ephemeral; teardown
destroys the model cache and every Prometheus series with it.

1. `make archive` - pulls the Prometheus TSDB, Grafana state and all
   `bench/out/*.json` to the local `archive/` directory.
2. Verify: `archive/prometheus-data.tgz`, `archive/grafana-data.tgz`, and one
   JSON per level are present locally. **List them.**
3. Confirm the archive replays: `cd archive && docker compose config`.
4. Report total elapsed time and cost.
5. **Then stop.** `make destroy` is in the `deny` list. Propose it and let the
   human run it.
