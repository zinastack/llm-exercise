# 004 - Tasks

- [x] Container added, pointed at vLLM, routed at `chat.<domain>`
- [x] **Bug: unusable login page.** `ENABLE_SIGNUP=false` was set before any
      account existed. Open WebUI promotes the *first* user to admin, so closing
      signup beforehand leaves an account that can never be created
- [x] **Worse: the setting persists into its SQLite database on first boot**, so
      changing the environment variable afterwards has no effect. The volume had
      to be recreated
- [x] `make webui-admin` now does it in the correct order: open signup → create
      the first account via the API → close signup
- [x] Verified reachable over HTTPS with a working login
