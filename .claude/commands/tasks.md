---
description: Break an approved plan into executable, verifiable tasks
---

Read `specs/$1/plan.md`, then write `specs/$1/tasks/vN-<short-name>.md`.

**`tasks/` is a folder, and earlier versions are never edited.** Find the highest
existing `vN` and write `v(N+1)`. If none exists, write `v0`.

Each task must have:
- A **verification** - the command that proves it worked, usually a `make` target.
- A **blocker** if it depends on a human - credential, approval, or an
  irreversible action.

Within the current version file, mark tasks done as work proceeds and **record
failures in place rather than deleting them.** A task that failed and was
rerouted is part of the engineering record - the three flag failures caught by
`make smoke` are worth more in the writeup than a clean list would be.

When the design changes rather than the progress, **write a new version file**
instead of editing the old one. Superseded reasoning is the most useful thing in
the folder.
