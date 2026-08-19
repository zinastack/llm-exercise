# Reproducibility

A number nobody else can reproduce is an anecdote.

## Rules

- **Pin the image by digest.** `VLLM_IMAGE` is a `sha256:` reference. `latest`
  silently changes the thing under measurement.
- **Record configuration inside the result.** Each `bench/out/*.json` carries the
  model, flags, environment and workload that produced it, so configuration
  cannot drift from its numbers.
- **Capture the engine's own decisions.** `bench/out/<level>.startup.txt` holds
  vLLM's reported KV cache size and maximum concurrency - the most informative
  output of the whole exercise and impossible to reconstruct afterwards.
- **Everything is a `make` target.** If it happened once in a terminal and matters,
  it belongs in the `Makefile`. Slash commands wrap `make`, never raw `docker`
  or `ssh`.
- **Prefer ungated, openly licensed artefacts** where they serve equally well -
  a reader who cannot obtain the model cannot reproduce the result.
