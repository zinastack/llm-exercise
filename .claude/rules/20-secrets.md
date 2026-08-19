# Secrets

## Rules

- **`.env` is never committed, never read into context, never echoed.** It is in
  `.gitignore` and in the `deny` list of `.claude/settings.json`.
- **Never print a token**, even partially, even in a diagnostic. Report
  *capability* instead: `content=403` rather than the token that produced it.
- **Never write a credential into a document**, including as an example. Examples
  use obviously-fake placeholders (`hf_xxxx`, `eyJhIjoi...`).
- **Scan before publishing or pushing** - names, hostnames, internal references,
  credentials. Check history too, not just the working tree: untracking a file
  leaves it in every earlier commit.
- **The API key protects a public endpoint.** An unauthenticated LLM endpoint is
  scanned and abused within hours. `--api-key` is not optional.
