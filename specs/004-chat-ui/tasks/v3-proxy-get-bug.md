# v3 - the proxy broke model listing

**Changes from [v2](v2-tool-injection.md)**

## Problem

The UI still failed after v2, and for a reason introduced *by* v2:

```
Connection error: 500, message='Attempt to decode JSON with unexpected mimetype:
text/plain; charset=utf-8', url='http://chat-proxy:8010/v1/models'
```

The proxy passed **both** `json=` and `data=` to aiohttp on every request.
aiohttp rejects that combination, the handler raised, and aiohttp's default error
page returned **HTTP 500 as `text/plain`**.

`GET /v1/models` is how Open WebUI discovers what it can serve. With that failing
it had **no working model connection**, so it fell back to its own knowledge-base
tools - producing exactly the symptom v2 set out to remove.

## Two constraints on anything sitting in this path

**A bodyless request must stay bodyless.** `GET` carries no payload, and aiohttp
rejects `json=` and `data=` together - so a passthrough must pass neither.

**Error responses must be JSON.** An OpenAI-compatible client parses failures as
JSON; a plaintext 500 surfaces downstream as a mimetype complaint rather than the
real fault, which is how a broken model listing presents as a model behaviour
problem.

## Change

```python
kwargs = {"headers": headers}
if isinstance(body, dict):
    kwargs["json"] = body        # JSON body - strip tools, re-encode
elif raw:
    kwargs["data"] = raw         # opaque body - pass through
# bodyless (GET): neither
```

Plus a `try/except` returning **JSON** on failure, a `/healthz` endpoint, and
hop-by-hop headers filtered on both directions.

## Verified

| Check | Result |
|---|---|
| `GET /v1/models` through the proxy | `200`, `models: ['target']` |
| Chat via Open WebUI as a logged-in user | returns Go source |
| Proxy log | `chat: stripped=nothing` |

## Operational note

**Anything inserted into a request path must be exercised against every method it
will carry**, not only the one it was added for - and its failure responses must
match the content type its clients parse. A passthrough that is correct for POST
and broken for GET fails in a way that looks like an application bug rather than
a transport one.
