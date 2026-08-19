# v4 - the UI was slow, the model was not

**Changes from [v3](v3-proxy-get-bug.md)**

## Measurement first

Before changing anything, each hop was measured with a single-process client -
an earlier attempt spawned a subprocess per token and measured its own overhead
at 9 tok/s, which was wrong by a factor of five.

| Path | Rate | Inter-token gap | TTFT |
|---|---:|---:|---:|
| Direct to vLLM | **54 tok/s** | p50 18 ms | 0.04 s |
| Through the proxy | same | same | - |
| **Through Cloudflare** | **50 tok/s** | p50 18 ms | 0.31 s |

**The serving path was never slow.** Cloudflare costs roughly 4 tok/s and 0.27 s
of TTFT - nothing that would be perceived as sluggish.

## Cause

Open WebUI issues **additional inference calls per message**: chat title
generation, tag generation, follow-up suggestions, autocomplete, and query
rewriting for retrieval. Each is a full round-trip against a 70B model.

A reply that generates in three seconds does not settle for twelve, because four
more requests queue behind it - against the same engine, competing with the
generation the user is waiting on.

## Change

Disabled in `docker-compose.yml`:

```
ENABLE_TITLE_GENERATION, ENABLE_TAGS_GENERATION, ENABLE_FOLLOW_UP_GENERATION,
ENABLE_AUTOCOMPLETE_GENERATION, ENABLE_SEARCH_QUERY_GENERATION,
ENABLE_RETRIEVAL_QUERY_GENERATION, ENABLE_WEB_SEARCH, ENABLE_RAG_WEB_SEARCH
```

Applied via `make webui-reset`, because Open WebUI persists configuration into
its database on first boot and environment variables only seed it - the same
behaviour that caused [v1](v1-demo-endpoint.md) and [v3](v3-proxy-get-bug.md).

## Operational note

**"Slow" is a symptom, not a location.** Measuring each hop separately showed the
inference stack performing exactly as benchmarked and located the cost in the
client - which no amount of vLLM tuning would have improved.
