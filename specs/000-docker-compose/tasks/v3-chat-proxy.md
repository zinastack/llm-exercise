# v3 - sanitising proxy, and restart policies

**Changes from [v2](v2-docker-compose.md)**

## Added: `chat-proxy`

```
open-webui → chat-proxy:8010 → vllm:8000
```

Open WebUI injects its own tool definitions into every request. Once tool calling
was enabled on vLLM the model began calling them instead of answering. The proxy
strips `tools`, `tool_choice`, `functions`, `function_call` and
`parallel_tool_calls`, forwarding everything else - including streaming -
untouched.

`open-webui`'s `OPENAI_API_BASE_URL` moved from `http://vllm:8000/v1` to
`http://chat-proxy:8010/v1`. Full reasoning in
[`specs/004-chat-ui/tasks/v2-tool-injection.md`](../../004-chat-ui/tasks/v2-tool-injection.md).

## Changed: restart policies

Every long-lived service is now `unless-stopped`, applied to the already-running
containers with `docker update` so the serving instance was not disturbed.

**vLLM is deliberately asymmetric**, set in `scripts/run.sh`:

| Mode | Policy | Why |
|---|---|---|
| Benchmark run | `--restart=no` | A crash mid-measurement must surface as a failed result, never be silently restarted into a corrupted number |
| `--keep` (demo endpoint) | `--restart=unless-stopped` | An unattended link that dies at 3am is worse than no link |

## Current services

`prometheus` · `grafana` · `dcgm-exporter` · `chat-proxy` · `open-webui` ·
`cloudflared` *(profile: public)* · `vllm` *(managed by `scripts/run.sh`, not compose)*
