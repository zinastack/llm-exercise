# 003 - Plan

**Cloudflare Tunnel.** `cloudflared` makes an outbound-only connection to the
edge - no inbound ports, works behind any firewall, independent of the provider's
networking model.

| Hostname | Serves | Auth | Why |
|---|---|---|---|
| `llm-dash.*` | Grafana | Cloudflare Access | Browser consumer - interactive login is appropriate |
| `chat.*` | Open WebUI | own login | Browser consumer |
| `llm.*` | vLLM API | `--api-key` bearer | Machine consumer - Access would break `curl` |

## TLS

Terminated at the Cloudflare edge, certificate issued and renewed automatically
(Universal SSL, Let's Encrypt). **No certificate on the origin**, and no
`noTLSVerify` - the only plaintext hop is `cloudflared → container` on a Docker
bridge with no route off the host.

Verified on the live zone before building: an existing subdomain already served
a valid Let's Encrypt chain under exactly this pattern.
