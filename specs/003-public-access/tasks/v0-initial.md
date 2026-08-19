# 003 - Tasks

- [x] Tunnel created, token in `.env`, cloudflared behind a compose profile so
      the stack runs without a Cloudflare account
- [x] Routes added under **Published application routes** - the tab moved in the
      current Cloudflare UI; *Hostname routes* is private-network routing
- [x] Verified `302` + valid TLS on the dashboard hostname
- [x] **`dash.*` collided with an existing DNS record** belonging to another
      tunnel. Hostnames made configurable (`DASH_HOST`, `LLM_HOST`, `CHAT_HOST`)
      and moved to `llm-dash.*` rather than deleting a record in use
- [x] Confirmed Universal SSL covers one subdomain level only - no nesting
