# Scope

The exercise says: *"This exercise is about serving and deployment engineering -
you will not be training or modifying model weights."*

## Rules

- **Configuration changes only, in the main progression.** Flags, cache formats,
  scheduling. Never fine-tuning, never re-quantizing, never editing weights.
- **Quantization is a separate category and is labelled as such.** Serving a
  published INT4 checkpoint is a deployment decision; presenting it as a tuning
  *level* blurs a line the exercise draws explicitly. It appears as a comparison
  with its caveat attached.
- **Do not silently expand scope.** The chat UI was added because a reviewer
  clicking a link should not get a 404 - but it is named as beyond the written
  requirements rather than folded in.
- **Do not silently narrow scope either.** If a required deliverable cannot be
  produced, say which one and why, in `docs/DELIVERABLES.md`.
- **Answer the question asked.** When a design is challenged, re-read the source
  text before defending the design. The scope error in this project was caught
  that way.
