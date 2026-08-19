# 004 - Plan

**Open WebUI**, one container on the same network, pointed at
`http://vllm:8000/v1` with the API key. Backend-down is handled gracefully, so it
survives vLLM cycling between levels.

Routed at `chat.<domain>` so the raw API stays available at `llm.<domain>` for
`curl` and the benchmark client.

## Risk

Adding a container to the measurement host could perturb results. Mitigated: it
is idle during benchmarks and holds no GPU.
