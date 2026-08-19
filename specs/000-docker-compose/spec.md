# 000 - The stack

**Status:** done

## Problem

Every other feature needs somewhere to run: an inference server, metrics
collection, dashboards, public exposure, a chat UI. That composition is itself an
artefact with its own decisions, and those decisions need to be revisable without
re-deriving them.

## Success criteria

1. The whole stack comes up with one command on a fresh host.
2. Observability survives vLLM restarting between benchmark levels.
3. It runs without a Cloudflare account, so it can be smoke-tested locally.
4. Named volumes survive refactoring of the repository layout.

## Why compose and not Kubernetes

Single node, short-lived. Compose is up in seconds with no control plane to
install or maintain. Kubernetes would buy scheduling, self-healing and multi-node
placement - none of which a single-node benchmark needs, all of which add moving
parts between the measurement and the hardware.

Reaching for Kubernetes here would be reflex, not judgement.

## Out of scope

High availability, rolling updates, multi-node scheduling, secret management
beyond a gitignored `.env`.
