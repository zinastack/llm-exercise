# v2 - stop the UI injecting tools

**Changes from [v1](v1-demo-endpoint.md)**

## Problem

After v1 enabled tool calling, the model stopped answering questions:

```
Explored 5 search_knowledge_bases, 5 query_knowledge_bases
I cannot provide a function call that will give a correct answer.
```

Open WebUI injects its own tool definitions - knowledge-base search, web search -
into every chat request. Once the model *could* call tools, it dutifully tried
to, found no knowledge bases, and reported failure instead of answering.

**The first diagnosis was incomplete.** vLLM rejecting `tool_choice` is one
symptom of a client and server disagreeing about tool support; enabling tool
calling resolves that symptom and exposes the next one. The requirement is not
that tools work - it is that a UI-injected tool surface never reaches a model
with nothing to call.

## Why the obvious fixes do not work

| Approach | Fails because |
|---|---|
| Remove the vLLM tool flags | Open WebUI still sends `tool_choice` → HTTP 400 |
| Turn tools off in the UI | Per-model setting stored in Open WebUI's database, not reachable from configuration |

## Change

A small sanitising proxy (`proxy/sanitize.py`, ~50 lines) between the UI and
vLLM. It strips `tools`, `tool_choice`, `functions`, `function_call` and
`parallel_tool_calls`, and passes everything else - streaming, headers, status
codes - through untouched.

```
open-webui → chat-proxy:8010 → vllm:8000
```

The UI may offer whatever it likes; the model never sees it.

## Verified

Sent the exact Open WebUI payload - `tool_choice: auto` plus a
`search_knowledge_bases` tool definition:

```
tool_calls: None
content: ```go
         package main
         func factorial(n int) int { ... }
```

## Why a proxy rather than configuration

Open WebUI stores this setting in its database and the shape has changed between
releases, so configuration is neither deterministic nor greppable. A proxy is
explicit in the compose file, reviewable in fifty lines, and independent of the
client's version - the right trade for an endpoint that has to behave
predictably in front of someone else.
