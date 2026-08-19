#!/usr/bin/env bash
# Persistent observability: Prometheus + Grafana + DCGM + Cloudflare Tunnel.
# Brought up once and left running across every tuning level.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -f .env ]] || { echo "cp .env.example .env and fill it"; exit 1; }
set -a; source .env; set +a

case "${1:-up}" in
  up)
    docker network inspect exercise-net >/dev/null 2>&1 || docker network create exercise-net
    python3 observability/make_dashboard.py
    if [[ -n "${TUNNEL_TOKEN:-}" ]]; then
      docker compose -f docker-compose.yml --profile public up -d
    else
      echo "note: TUNNEL_TOKEN unset -> starting WITHOUT the public tunnel"
      docker compose -f docker-compose.yml up -d
    fi
    echo
    echo "  grafana   https://${DASH_HOST:-llm-dash.zinalacina.com}   (put Cloudflare Access on this)"
    echo "  model     https://${LLM_HOST:-llm.zinalacina.com}    (after: make final)"
    echo
    echo "Tunnel -> Published application routes. Type HTTP, no scheme in the URL:"
    echo "  ${DASH_HOST:-llm-dash.zinalacina.com}  ->  grafana:3000"
    echo "  ${LLM_HOST:-llm.zinalacina.com}   ->  vllm:8000"
    ;;
  down) docker compose -f docker-compose.yml down ;;
  logs) docker compose -f docker-compose.yml logs -f ;;
  *) echo "usage: ./stack.sh up|down|logs"; exit 1 ;;
esac
