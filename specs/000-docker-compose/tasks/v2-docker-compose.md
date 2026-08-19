# v2 - root level, pinned project, ordered bootstrap

**Changes from [v1](v1-docker-compose.md)** · **Location:** `./docker-compose.yml`

## Moved to the repository root

The compose file *is* the artifact. Burying it under `observability/` made the
directory look like the point when it is a supporting detail.

## ⚠ The near-miss this caused

Compose derives its project name from the parent directory. Moving the file
renamed the project `observability` → `rafay-exercise`, which would have
**orphaned `observability_prom-data` and destroyed the entire Prometheus history
for every benchmark already run.**

Fixed by pinning it explicitly:

```yaml
name: observability
```

**Generalisable lesson:** moving a compose file is not a refactor. It silently
rebinds every named volume unless the project name is pinned.

## Fixed the Open WebUI bootstrap

`ENABLE_SIGNUP` is now `${WEBUI_ENABLE_SIGNUP:-true}`, and a `make webui-admin`
target performs the sequence that actually works:

1. Start with signup **open**
2. `POST /api/v1/auths/signup` - first user is auto-promoted to admin
3. Close signup and restart

Order matters, and it is not recoverable by editing environment variables later
because the setting lives in the database.

## Current services

`prometheus` · `grafana` · `dcgm-exporter` · `open-webui` · `cloudflared` *(profile: public)*
