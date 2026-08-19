# v1 - the demo endpoint

**Changes from [v0](v0-initial.md)**

## Problem

The chat UI loaded, then failed on the first message:

```
"auto" tool choice requires --enable-auto-tool-choice and --tool-call-parser to be set
```

Open WebUI sends `tool_choice: auto` on **every** request. vLLM returns HTTP 400
unless a tool parser is configured. Compounding it: vLLM was not running at all -
each benchmark level tears its own server down when it finishes.

## Change

A dedicated **`serve`** configuration in `scripts/configs.sh`, deliberately **excluded
from `TUNING_LEVELS`** so it can never contaminate a measurement. Two differences
from `L3-schedule`, both intentional:

| | Why |
|---|---|
| `--enable-auto-tool-choice --tool-call-parser llama3_json` | The actual fix |
| INT4 weights instead of FP16 | ~20 ms TPOT versus ~50 ms. A demo should feel responsive; the FP16 comparison lives in the results |

## Reliability for an unattended window

Benchmark runs use `--restart=no` on purpose - a crash mid-measurement must
surface as a failed result, not be silently restarted into a corrupted number.

The demo endpoint is the opposite case: it must survive hours unattended, so
`--keep` now implies `--restart=unless-stopped`. **A link that dies at 3am is
worse than no link**, and you do not control when a reviewer clicks it.

## Verified

- Streamed completion through `https://llm.zinalacina.com` - Go factorial, tokens
  arriving incrementally
- The exact Open WebUI payload shape (`tool_choice: auto` + a tools array)
  streams successfully
- Zero `400` responses in Open WebUI logs afterwards

## Hardware note

The benchmark requires 2× A100 with NVLink. **The demo does not** - INT4 is
~35 GB and fits on a single GPU with no tensor parallelism, so no interconnect is
involved at all. That is the NVLink argument from `REPORT.md` §6 seen from the
serving side: once the model fits on one device, tensor parallelism stops earning
its synchronisation cost.
