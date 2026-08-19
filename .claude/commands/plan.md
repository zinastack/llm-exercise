---
description: Turn an approved spec into an implementation plan with explicit mechanisms
---

Read `specs/$1/spec.md`, then write `specs/$1/plan.md`.

For each proposed change:

- **Mechanism** - *why* it should work, in one sentence. A change without a
  stated mechanism is a guess; guesses do not become tuning levels.
- **Expected signature** - what should move in the metrics, and what should not.
  Being specific here is what makes a null result informative later.
- **Duration** - wall clock, and what it blocks.
- **Risk** - what breaks, and how it would be detected.

Then:
- Order the work so the **fastest check capable of invalidating the rest** runs
  first.
- Identify the single validation that de-risks the most (here: `make smoke`).
- Flag anything requiring a human decision, a credential, or an irreversible
  action.

Stop and ask for review before writing tasks.
