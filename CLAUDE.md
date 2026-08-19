# CLAUDE.md

Working agreement for AI-assisted work in this repository.

I organised this repository and leveraged Claude Code to speed up writing the
scripts and code. That is stated openly rather than concealed.

What follows is the discipline the tool was held to - the guardrails, the
permission boundaries, and the specification-first workflow. **The point is not
that AI was used; it is that it was used under constraints a reviewer can
inspect, on work whose direction, decisions and trade-offs remain mine.**

---

## What this repository is

A benchmark of **Llama-3.1-70B-Instruct served on 2× NVLink-connected A100 80GB**
via vLLM: a baseline at default settings, then measured improvements to output
token throughput and TTFT through deployment configuration alone.

Read `specs/001-llm-serving/spec.md` before changing anything. It states
the *what* and *why*; `plan.md` states the *how*; `tasks.md` tracks execution.

---

## Non-negotiables

These are enforced in `.claude/rules/` and repeated here because they are the
ones that matter most:

1. **Never hand-type a measurement.** Every number in `RESULTS.md` and
   `REPORT.md` is generated from `bench/out/*.json`. If a figure cannot be traced
   to a file, it does not go in a document.
2. **A failed run is a result.** `fp16-baseline` refusing to start *is* the
   Part 1 finding. Record it; never quietly retry until something succeeds.
3. **Never commit secrets.** `.env` is gitignored. Tokens are never echoed, never
   pasted into documents, never included in a commit.
4. **The host is rented and ephemeral.** Validate at small scale before
   committing to long-running work, archive before teardown, and never leave it
   idle.
5. **State uncertainty explicitly.** Where a claim is not measured, mark it as
   unmeasured. The honest gaps in `docs/DELIVERABLES.md` are part of the deliverable.

---

## Conventions

**Everything is a `make` target.** If an operation is worth doing twice it
belongs in the `Makefile`, not in a chat transcript. Slash commands in
`.claude/commands/` wrap `make`, never raw `docker` or `ssh`.

**Configuration lives in `scripts/configs.sh`.** One entry per tuning level, each with a
one-line rationale that explains the *mechanism*, not just the flag. A level
without a stated mechanism is not a level.

**Reproducibility is a hard requirement.** The vLLM image is pinned by digest.
Model, flags, environment and workload are recorded *inside* the result file, so
configuration cannot drift from the numbers it produced.

**Identical conditions across runs.** Same prompts, same output length, same
concurrency levels, same warm-up - enforced in `scripts/run.sh` rather than by
convention. A comparison is only valid if the only thing that changed is the
thing under test.

---

## How I used it

Stated plainly, so a reviewer can judge it rather than guess:

| Used for | Retained by me |
|---|---|
| Writing the harness, report generator and stack from my design | What is measured, and what counts as a valid result |
| Executing diagnostics I directed - SSH, disk, flags, token scope | The diagnosis itself, and which hypothesis to test |
| Drafting prose from measured output | Every engineering decision and trade-off |
| Producing candidate tuning levels against my criteria | Which levels are in scope, and why |

**I corrected the tool's proposals several times**, most significantly the scope
error where quantization had been made a tuning level despite the exercise
stating that weights must not be modified. I also rejected the initial hardware
choice on disk capacity, and pushed back on a benchmark workload that turned out
not to constrain the system. Those corrections are recorded in
`specs/001-llm-serving/spec.md` and in the commit history rather than
smoothed away - they are the part of the record that shows judgement.

---

## If you are an agent working here

- Read the spec before the code.
- Prefer `make <target>` over ad-hoc commands.
- Before anything irreversible - provisioning, deleting a volume, destroying an
  instance - say what it will do and ask.
- When a result contradicts a hypothesis in the documentation, **change the
  documentation, not the result.**
