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
(Universal SSL, Let's Encrypt). **No certificate on the origin.** Everything
behind `cloudflared` is plaintext on the Docker bridge, with no published ports
and vLLM bound to `127.0.0.1` - nothing is reachable off the host.

`cloudflared` supports `caPool`/`originServerName`, so origin TLS against an
internal CA was possible without `noTLSVerify`. Not worth the CA distribution on
a single ephemeral host; the persistent cluster on this domain terminates at the
origin instead, where traffic actually crosses nodes.

Verified on the live zone before building: an existing subdomain already served
a valid Let's Encrypt chain under exactly this pattern.
