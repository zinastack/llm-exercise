# specs/

**Every feature has the same shape.** No exceptions - uniformity is what makes
the directory navigable by someone who has never seen it, human or LLM.

```
NNN-feature/
├── spec.md      WHAT and WHY        - no implementation detail
├── plan.md      HOW                 - mechanisms, costs, risks
└── tasks/       WHAT HAPPENED       - one file per version
    ├── v0-....md
    ├── v1-....md
    └── v2-....md
```

## Why `tasks/` is a folder, not a file

A single `tasks.md` gets rewritten as work proceeds, and **the reasoning behind
superseded decisions is lost with each edit.** A folder keeps every revision:

- `v0` records the original state and why it was built that way
- `v1` records what changed, why, and what broke
- `v2` records the next change, on top of the previous

The old version is never deleted. Reading `v0 → v1 → v2` reconstructs how the
design arrived at its current shape - including the constraints discovered along
the way, which are usually the most useful part to a reader.

**Example:** `000-docker-compose/tasks/` runs v0 initial stack → v1 chat UI and
optional tunnel → v2 root level and pinned project name. That v2 file records a
near-miss where moving the compose file would have orphaned the Prometheus
volume and destroyed every measurement taken up to that point. A rewritten
`tasks.md` would not contain that.

## Features

| # | Feature | Versions | Status |
|---|---|---|---|
| [000](000-docker-compose/) | The stack - composition, layout, operational interface | v0 · v1 · v2 · v3 · v4 | done |
| [001](001-llm-serving/) | Benchmark 70B serving on 2× NVLink A100s | v0 provisioning · v1 INT4 · v2 FP16 · v3 reporting fix | done |
| [002](002-observability/) | Metrics, dashboards-as-code, offline archive | v0 · v1 metric renames · v2 empty panels | done |
| [003](003-public-access/) | Public HTTPS without opening a port | v0 | done |
| [004](004-chat-ui/) | Chat interface over the served model | v0 · v1 demo endpoint · v2 tool injection · v3 proxy GET bug · v4 perceived latency | done |

## Adding a feature or a version

```bash
/spec  005-my-feature   "what and why"
/plan  005-my-feature   # after the spec is reviewed
/tasks 005-my-feature   # writes tasks/v0-*.md
```

For a subsequent revision, add `tasks/vN-*.md` describing what changed and why.
**Never edit an earlier version in place** - that is the whole point of the
folder.

## Rules for these documents

- **`spec.md` contains no implementation detail.** If it names a flag, it belongs
  in `plan.md`.
- **`plan.md` states a mechanism for every change.** A change without one is a
  guess, and guesses do not become tuning levels.
- **`tasks/` records what each gate found.** Provider SSH behaviour, disk
  provisioning semantics, a changed vLLM flag surface, Hugging Face's split
  between licence approval and token scope - all documented so the next person
  running this does not rediscover them.
