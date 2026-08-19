# v1 - chat UI, optional tunnel

**Changes from [v0](v0-docker-compose.md)**

> **Paths in this file are as they were at v1.** See [v4](v4-layout.md) for the
> current layout.


## Added

**`open-webui`** - the API returns `404` in a browser. A reviewer clicking a link
should get something usable, so a chat interface was put over the same endpoint.
Named as beyond the written requirements rather than folded in silently.

## Changed

**`cloudflared` moved behind a compose profile.** It requires a tunnel token,
which blocked local smoke testing. Now `stack.sh` starts it only when
`TUNNEL_TOKEN` is set, so the stack runs without any Cloudflare account.

**Hostnames became explicit `.env` values** (`DASH_HOST`, `LLM_HOST`,
`CHAT_HOST`) rather than being derived from `DOMAIN`. Prompted by
`dash.zinalacina.com` colliding with an existing DNS record belonging to another
tunnel - a name that was already in use and should not have been deleted.

## Problems found

**`ENABLE_SIGNUP: "false"` with no existing user.** Open WebUI promotes the first
account to admin; closing signup beforehand leaves a login page for an account
that can never be created. Worse, the setting is **persisted into its SQLite
database on first boot**, so changing the environment variable afterwards has no
effect. Fixed in [v2](v2-docker-compose.md).
