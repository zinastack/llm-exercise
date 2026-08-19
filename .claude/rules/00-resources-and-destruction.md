# Resources and destructive operations

The GPU host is **rented and ephemeral**. Its local NVMe is wiped on teardown,
taking ~170 GB of model cache with it. Nothing on that machine is durable.

## Rules

- **Never run `make destroy` autonomously.** It is in the `deny` list. Propose it;
  the human runs it.
- **Always `make archive` before teardown.** Prometheus history, Grafana state and
  every result must be off the host first. Teardown is irreversible.
- **Validate at small scale first.** Prove the pipeline with a 1.5 B model before
  committing to a 141 GB download and a multi-hour run. `make smoke` exists for
  this and has surfaced three environment differences that would otherwise have
  appeared only after the download completed.
- **Check capacity before provisioning, not just availability.** An instance type
  whose disk cannot hold the weights is not a candidate regardless of anything
  else. `make capacity` reports disk range alongside availability.
- **Never leave the host idle.** If work is blocked on a human decision, say so
  and offer teardown rather than letting it run unused.
- **Confirm before anything irreversible** - provisioning, deleting a volume,
  destroying an instance, force-pushing.
