---
description: Provision, verify and bring up the inference stack - with cost gates
---

Bring up the serving stack. **Every step is a `make` target; never raw docker or ssh.**

1. `make capacity` - check disk range and availability. An instance type whose
   disk cannot hold the weights is not a candidate.
2. **Ask before provisioning.**
3. `make provision`
4. `make doctor` - **the gate.** Instance state, SSH, GPUs, docker + nvidia
   runtime, disk, startup log. If SSH fails, propose teardown rather than
   debugging against an unreachable host.
5. `make topo` - confirm `NV12`. Anything else and the NVLink premise is gone;
   stop and report.
6. `make sync`
7. `make stack` - Prometheus, Grafana, DCGM, tunnel.
8. `make smoke` - tiny model, proves the whole pipeline before committing to a
   141 GB download.

If blocked on a human decision, say so and offer teardown rather than idling.
