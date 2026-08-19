# 004 - Chat UI

**Status:** done · **Scope:** beyond the written exercise, stated as such

## Problem

`llm.<domain>/` returns `{"detail":"Not Found"}` in a browser. It is an
OpenAI-compatible REST API, not a page. A reviewer clicking a link gets a 404,
which is worse than not sending one.

## Success criteria

1. A working chat interface over the same served model.
2. Its own authentication - the hostname is public.
3. Survives vLLM restarting between benchmark levels.
4. Does not interfere with the benchmark or its measurements.

## Out of scope

RAG, document upload, multi-model routing, conversation persistence guarantees.
