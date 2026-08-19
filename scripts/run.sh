#!/usr/bin/env bash
# one level: relabel prometheus, start vllm, benchmark, tear down.
#
#   ./scripts/run.sh baseline
#   ./scripts/run.sh serve --keep    # leave it running
#
# stack.sh stays up across levels.
set -euo pipefail
cd "$(dirname "$0")/.."

source ./scripts/configs.sh
[[ -f .env ]] || { echo "cp .env.example .env and fill it"; exit 1; }
set -a; source .env; set +a

NAME="${1:?usage: ./run.sh <level> [--keep]}"
KEEP="${2:-}"
entry="$(config_get "$NAME")" || {
  echo "unknown level: $NAME"; echo "available:"; config_names | sed 's/^/  /'; exit 1; }

IFS='|' read -r _ model_var extra_env flags rationale <<< "$entry"
MODEL="${!model_var}"
CONTAINER="vllm"
OUT="bench/out"
mkdir -p "$OUT"

echo "══════════════════════════════════════════════════════════════════"
echo " level  : $NAME"
echo " model  : $MODEL"
echo " flags  : ${flags:-<vLLM defaults>}"
echo " env    : ${extra_env:-<none>}"
echo " why    : $rationale"
echo "══════════════════════════════════════════════════════════════════"

docker network inspect exercise-net >/dev/null 2>&1 || docker network create exercise-net
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true

# tag this run so all levels land on the same panels
cat > observability/targets/vllm.json <<JSON
[
  {
    "targets": ["vllm:8000"],
    "labels": {
      "level": "${NAME}",
      "model": "$(basename "$MODEL")"
    }
  }
]
JSON
curl -fsS -X POST http://localhost:9090/-/reload >/dev/null 2>&1 \
  && echo "prometheus relabelled -> level=${NAME}" \
  || echo "note: prometheus not reachable yet (file_sd will pick it up in 5s)"

env_args=()
if [[ -n "$extra_env" ]]; then
  IFS=',' read -ra pairs <<< "$extra_env"
  for p in "${pairs[@]}"; do env_args+=(-e "$p"); done
fi

# shellcheck disable=SC2086
# no restart on benchmarks - a crash should show up as a failed result.
# --keep is the demo endpoint and needs to survive unattended.
RESTART="--restart=no"
[[ "$KEEP" == "--keep" ]] && RESTART="--restart=unless-stopped"

docker run -d --name "$CONTAINER" $RESTART \
  --network exercise-net \
  --gpus all --ipc=host --shm-size=16g \
  -p 127.0.0.1:8000:8000 \
  -v "${HF_CACHE:-/mnt/models/huggingface}:/root/.cache/huggingface" \
  -e "HUGGING_FACE_HUB_TOKEN=$HF_TOKEN" \
  -e "VLLM_WORKER_MULTIPROC_METHOD=spawn" \
  "${env_args[@]}" \
  "${VLLM_IMAGE:-vllm/vllm-openai:latest}" \
    "$MODEL" \
    --served-model-name target \
    --tensor-parallel-size 2 \
    --api-key "$API_KEY" \
    --no-enable-log-requests \
    --host 0.0.0.0 --port 8000 \
    $flags >/dev/null
    # model is positional now. no-enable-log-requests because per-request
    # logging skews things at c=64. do NOT disable log-stats, prometheus
    # needs it.

# a config that won't start is a result, so it gets the same artefacts as one
# that does: the logs on disk and a json next to the others. the reason only
# exists in these logs, so keep a long tail rather than a summary.
record_failure() {
  local why="$1"
  docker logs --tail 200 "$CONTAINER" > "$OUT/${NAME}.startup.txt" 2>&1 || true
  tail -20 "$OUT/${NAME}.startup.txt" || true
  local err
  err=$(grep -Ei 'error|exception|cannot|larger than|out of memory' \
          "$OUT/${NAME}.startup.txt" | tail -3 | tr -s '\n' ' ')
  python3 - "$NAME" "$MODEL" "$flags" "$rationale" "$why" "$err" <<'PY'
import json, sys, pathlib
n, m, f, r, why, err = sys.argv[1:7]
pathlib.Path("bench/out").mkdir(parents=True, exist_ok=True)
p = pathlib.Path("bench/out")/f"{n}.json"
p.write_text(json.dumps({"config": n, "model": m, "flags": f, "rationale": r,
                         "startup": "FAILED", "failure": why,
                         "error": err.strip(), "levels": []}, indent=2))
print(f"recorded startup failure to {p}")
PY
}

echo -n "starting"
deadline=$(( SECONDS + 2400 ))
until curl -fsS -o /dev/null http://localhost:8000/health 2>/dev/null; do
  if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo " FAILED"; record_failure exited; exit 1
  fi
  printf '.'; sleep 15
  (( SECONDS < deadline )) || { echo " TIMEOUT"; record_failure timeout; exit 1; }
done
echo " healthy"

# vllm's own kv sizing, worth keeping
docker logs "$CONTAINER" 2>&1 \
  | grep -Ei 'kv cache|concurrency|blocks|graph capturing' | tail -20 \
  > "$OUT/${NAME}.startup.txt" || true
echo "--- vLLM sizing ---"; cat "$OUT/${NAME}.startup.txt" 2>/dev/null || true

python3 bench/benchmark.py \
  --base-url http://localhost:8000/v1 \
  --api-key "$API_KEY" --model target \
  --config-name "$NAME" --model-id "$MODEL" \
  --flags "$flags" --extra-env "${extra_env:-}" \
  --rationale "$rationale" \
  --levels "4:64,64:256,256:512" \
  --prompt-tokens 512 --max-tokens 256 \
  --out "$OUT/${NAME}.json"

if [[ "$KEEP" == "--keep" ]]; then
  echo
  echo "left running and reachable at https://${LLM_HOST:-llm.zinalacina.com}"
  echo "stop it with: docker rm -f $CONTAINER"
else
  docker rm -f "$CONTAINER" >/dev/null
fi
echo "done: $OUT/${NAME}.json"
