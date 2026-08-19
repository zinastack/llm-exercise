---
description: Run one tuning level, or the full progression, and regenerate results
---

Run: **$ARGUMENTS** (a level name, or `all`)

- One level → `make one LEVEL=<name>`
- Everything → `make levels`, then `make nvlink` for the control
- Always finish with `make report` to regenerate `RESULTS.md` from the raw JSON

Then:
- Read `bench/out/<level>.startup.txt` and report vLLM's **KV cache size** and
  **maximum concurrency**. These explain the numbers.
- Compare against the level's stated mechanism in `scripts/configs.sh`. **If the result
  contradicts the hypothesis, say so plainly** and update the documentation - do
  not reinterpret the measurement to fit.
- Report failures and timeouts explicitly. Never summarise them away.
