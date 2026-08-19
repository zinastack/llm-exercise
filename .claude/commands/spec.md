---
description: Create or update a feature specification - the what and the why, never the how
---

Write `specs/$1/spec.md` for: **$ARGUMENTS**

Structure it as:

1. **Problem** - what is being asked, quoting the source requirement verbatim
   where one exists. Quote it; do not paraphrase a requirement you will later be
   judged against.
2. **Constraints** - hardware, licence, cost, time. Include the arithmetic that
   makes the problem hard.
3. **Out of scope** - explicitly, especially where the source text draws a line.
4. **Success criteria** - measurable. "Improves throughput" is not a criterion;
   "output tok/s at concurrency 256 exceeds baseline" is.
5. **Open questions** - things that need a human decision.

Rules:
- **No implementation detail.** That belongs in `plan.md`.
- If a requirement is ambiguous, record both readings rather than silently
  choosing one.
- Then stop and ask for review. Do not proceed to a plan unprompted.
