SHELL := /bin/bash
INSTANCE ?= llm-exercise
# brev exec is unreliable (SSH exit 255). brev still writes a working ssh
# config, so drive the box through ssh/rsync directly.
SSH  := ssh -F $(HOME)/.brev/ssh_config -o StrictHostKeyChecking=no -o ConnectTimeout=20
RSYNC := rsync -az --delete --exclude .git --exclude bench/out --exclude .env \
           --exclude observability/targets
TYPE     ?= a2-ultragpu-2g:nvidia-a100-80gb:2
DISK     ?= 250
LEVEL    ?= baseline
REMOTE   ?= ~/rafay-exercise

.PHONY: help
help:
	@echo ""
	@echo "  FROM YOUR LAPTOP"
	@echo "    make provision      create the 2x A100 instance ($$ starts here)"
	@echo "    make status         is it ready yet?"
	@echo "    make sync           copy this folder up to the instance"
	@echo "    make doctor         check connectivity BEFORE relying on it"
	@echo "    make remote CMD='make topo'   run a command on the box (no ssh needed)"
	@echo "    make shell          interactive shell (beta; use remote if it fails)"
	@echo "    make capacity       2x A100 80GB availability and disk range"
	@echo "    make archive        pull Prometheus/Grafana + results down BEFORE teardown"
	@echo "    make destroy        DELETE the instance ($$ stops here)"
	@echo ""
	@echo "  ON THE INSTANCE  (cd ~/rafay-exercise)"
	@echo "    make topo           confirm NV12 between the two GPUs"
	@echo "    make weights        download both checkpoints (~176GB)"
	@echo "    make stack          Prometheus + Grafana + chat UI - leave up"
	@echo "    make webui-reset    recreate the chat UI DB (applies a new upstream URL)"
	@echo "    make smoke          tiny model, proves the pipeline works"
	@echo "    make levels         baseline -> L1 -> L2 -> L3, then report"
	@echo "    make one LEVEL=L2-quantize"
	@echo "    make int4           the INT4 progression (quantization comparison)"
	@echo "    make nvlink         the NVLink control run"
	@echo "    make final          re-run L3 and leave it serving publicly"
	@echo "    make report         bench/out/*.json -> RESULTS.md"
	@echo "    make down           stop everything on the box"
	@echo ""
	@echo "  LOAD TEST ANY ENDPOINT  (laptop, no GPU needed - pip install aiohttp)"
	@echo "    make ping     KEY=sk-...   is it up, and what is it serving?"
	@echo "    make loadtest KEY=sk-...   run the report's harness against it"
	@echo "      URL=$(URL)"
	@echo "      LEVELS=$(LEVELS)  PROMPT=$(PROMPT)  OUTPUT=$(OUTPUT)"
	@echo ""
	@source ./scripts/configs.sh 2>/dev/null && echo "  levels: $$(config_names | tr '\n' ' ')" || true
	@echo ""

# ─────────────────────────────── laptop ───────────────────────────────────
.PHONY: provision status sync doctor remote shell capacity destroy

provision:
	@echo "creating $(INSTANCE) [$(TYPE)] with $(DISK)GB disk"
	@read -rp "continue? [y/N] " ok; [[ "$$ok" == "y" ]] || exit 1; \
	brev create $(INSTANCE) --type "$(TYPE)" --min-disk $(DISK) --detached \
	  --startup-script @scripts/setup-node.sh

status:
	@brev ls | grep -E "NAME|$(INSTANCE)" || echo "no instance named $(INSTANCE)"

sync:
	@brev refresh >/dev/null 2>&1 || true
	@$(SSH) $(INSTANCE) 'mkdir -p $(REMOTE)'
	$(RSYNC) -e "$(SSH)" ./ $(INSTANCE):$(REMOTE)/
	@if [ -f .env ]; then scp -F $(HOME)/.brev/ssh_config .env $(INSTANCE):$(REMOTE)/.env && echo "  .env copied"; \
	 else echo "  NOTE: no local .env - create one on the box before running levels"; fi
	@$(SSH) $(INSTANCE) 'ls $(REMOTE)' | tr '\n' ' '; echo

# run this before trusting the connection
doctor:
	@echo "1. instance state"
	@brev ls | grep -E "NAME|$(INSTANCE)" || { echo "   NO INSTANCE"; exit 1; }
	@echo "2. refreshing ssh config"
	@brev refresh 2>&1 | tail -2 || true
	@echo "3. ssh reachability"
	@$(SSH) $(INSTANCE) 'echo "   OK: $$(hostname)"' 2>&1 | grep -v Pseudo || \
	  { echo "   SSH FAILED - destroy the box rather than let it idle"; exit 1; }
	@echo "4. gpus"
	@$(SSH) $(INSTANCE) 'nvidia-smi --query-gpu=index,name,memory.total --format=csv,noheader' 2>&1 | grep -v Pseudo | sed 's/^/   /'
	@echo "5. docker + nvidia runtime"
	@$(SSH) $(INSTANCE) 'docker info 2>/dev/null | grep -E "Server Version|Runtimes" | head -2' 2>&1 | grep -v Pseudo | sed 's/^/   /' \
	  || echo "   docker not ready yet - startup script may still be running"
	@echo "6. disk"
	@$(SSH) $(INSTANCE) 'df -h / | tail -1' 2>&1 | grep -v Pseudo | sed 's/^/   /'
	@echo "7. startup script tail"
	@$(SSH) $(INSTANCE) 'tail -4 /var/log/exercise-setup.log 2>/dev/null || echo "   (no log yet)"' 2>&1 | grep -v Pseudo | sed 's/^/   /' 

# drive the box without an interactive shell
#   make remote CMD='make topo'
remote:
	@test -n "$(CMD)" || { echo "usage: make remote CMD='make topo'"; exit 1; }
	@$(SSH) -t $(INSTANCE) 'cd $(REMOTE) && $(CMD)'

shell:
	@brev refresh >/dev/null 2>&1 || true
	$(SSH) -t $(INSTANCE) 'cd $(REMOTE) 2>/dev/null; exec bash -l'

# disk is what disqualifies a type, not availability. need ~205GB.
capacity:
	@brev search gpu --gpu-name A100 --json 2>/dev/null | python3 -c "\
import json,sys; rows=json.load(sys.stdin); \
two=[r for r in rows if r['gpu_count']==2 and r['vram_per_gpu_gb']>=80]; \
print('  no 2x A100 80GB available right now') if not two else None; \
[print(f\"  \$${r['price_per_hour']:>6.2f}/hr  {r['type']:36} {r['cloud']:12} \
disk={r['disk_min_gb']}-{r['disk_max_gb']}G {'OK ' if r['disk_max_gb']>=205 else 'TOO SMALL'} stoppable={r['stoppable']}\") \
 for r in sorted(two,key=lambda x:x['price_per_hour'])]; \
print('\\n  need >=205GB disk: 140GB FP16 weights + 35GB AWQ + 30GB overhead')"

# pull metrics off before teardown - local nvme is wiped
archive:
	@echo "==> snapshotting observability volumes"
	@$(SSH) $(INSTANCE) 'mkdir -p /mnt/models/backup && \
	  docker run --rm -v observability_prom-data:/d -v /mnt/models/backup:/b alpine \
	    tar czf /b/prometheus-data.tgz -C /d . && ls -lh /mnt/models/backup' | grep -v Pseudo
	@echo "==> pulling results + archive down"
	@mkdir -p archive bench/out
	@$(RSYNC) -e "$(SSH)" $(INSTANCE):$(REMOTE)/bench/out/ ./bench/out/
	@scp -F $(HOME)/.brev/ssh_config $(INSTANCE):/mnt/models/backup/'*.tgz' ./archive/
	@ls -lh archive/*.tgz bench/out/*.json | tail -20
	@echo "==> replay locally with: cd archive && docker compose up -d"

destroy: 
	@echo "run 'make archive' FIRST - the local NVMe is wiped on teardown."
	@echo "this DELETES $(INSTANCE) and everything on its local disk."
	@read -rp "type the instance name to confirm: " n; \
	[[ "$$n" == "$(INSTANCE)" ]] && brev delete $(INSTANCE) || echo "cancelled"

# ───────────────────────────── on the box ─────────────────────────────────
.PHONY: topo weights stack webui-admin webui-reset smoke levels one int4 nvlink final report down archive

topo:
	@nvidia-smi topo -m
	@echo ""
	@echo "  expect NV12 between GPU0 and GPU1 - 12 NVLink 3.0 links, 600 GB/s bidirectional"
	@echo "  anything else (PIX/PXB/PHB/SYS) means no NVLink and the exercise premise changes"
	@nvidia-smi nvlink -s 2>/dev/null | head -4 || true

# NB --exclude takes one pattern per flag. trailing positional args are read
# as files-to-fetch and you get a silent no-op.
weights:
	@set -a; . ./.env; set +a; \
	export PATH=$$PATH:$$HOME/.local/bin HF_HUB_ENABLE_HF_TRANSFER=1 HF_HOME=$${HF_CACHE%/*}; \
	pip3 install -q --break-system-packages hf_transfer huggingface_hub 2>/dev/null || true; \
	for m in $$MODEL_FP16 $$MODEL_AWQ; do \
	  echo "==> $$m"; \
	  hf download "$$m" --exclude "original/*" --exclude "*.pth" --exclude "*.gguf"; \
	done; \
	du -sh $$HF_CACHE/hub/* 2>/dev/null

stack:
	./scripts/stack.sh up

# open-webui writes its config to sqlite on first boot and env vars only seed
# it, so changing the upstream url means recreating the volume.
webui-reset:
	@set -a; . ./.env; set +a; \
	docker rm -f open-webui >/dev/null 2>&1 || true; \
	docker volume rm observability_webui-data >/dev/null 2>&1 || true; \
	WEBUI_ENABLE_SIGNUP=true docker compose up -d open-webui >/dev/null; \
	printf "waiting for open-webui"; \
	for i in $$(seq 1 40); do \
	  docker exec open-webui curl -fsS -o /dev/null http://localhost:8080/ 2>/dev/null && break; \
	  printf "."; sleep 5; done; echo " up"; \
	$(MAKE) webui-admin

# first account becomes admin, then close signup
webui-admin:
	@set -a; . ./.env; set +a; \
	code=$$(docker exec open-webui curl -s -o /tmp/r -w "%{http_code}" \
	  -X POST http://localhost:8080/api/v1/auths/signup \
	  -H 'Content-Type: application/json' \
	  -d "{\"name\":\"admin\",\"email\":\"$$WEBUI_EMAIL\",\"password\":\"$$WEBUI_PASSWORD\"}"); \
	echo "signup -> $$code"; \
	if [ "$$code" = "200" ]; then \
	  echo "  account created: $$WEBUI_EMAIL"; \
	  WEBUI_ENABLE_SIGNUP=false docker compose up -d open-webui >/dev/null 2>&1; \
	  echo "  signup closed"; \
	else docker exec open-webui cat /tmp/r; fi

# proves the pipeline before pulling 140GB
smoke: stack
	./scripts/run.sh smoke
	@echo ""
	@echo "  if that produced numbers, the pipeline is good:"
	@echo "    TP=2 works · prometheus labelled · grafana live · benchmark ok"
	@echo "  now safe to commit to the 70B download."

levels: stack
	@source ./scripts/configs.sh && for c in $$TUNING_LEVELS; do \
		echo; echo "### $$c"; ./scripts/run.sh $$c || echo "!! $$c failed - continuing"; \
	done
	@$(MAKE) report

one:
	./scripts/run.sh $(LEVEL)

nvlink:
	./scripts/run.sh fp16-nvlink-off

# int4, for the quantization comparison
int4:
	@source ./scripts/configs.sh && for c in $$INT4_LEVELS; do \
		echo; echo "### $$c"; ./scripts/run.sh $$c || echo "!! $$c failed"; done
	@$(MAKE) report

final:
	@source ./scripts/configs.sh && ./scripts/run.sh $$FINAL_LEVEL --keep

report:
	@python3 bench/report.py

down:
	-docker rm -f vllm
	./scripts/stack.sh down

# ─────────────────────── load test any endpoint ───────────────────────────
# Same harness that produced RESULTS.md, pointed wherever you like. Runs from
# a laptop - no GPU box, no docker, nothing from the sections above.
#
#   pip install aiohttp
#   make ping     KEY=sk-...
#   make loadtest KEY=sk-...
#
# Override anything:
#   make loadtest KEY=sk-... LEVELS=256:512 PROMPT=2048 OUTPUT=512
.PHONY: ping loadtest

URL     ?= https://llm.zinalacina.com/v1
KEY     ?= $(API_KEY)
MODEL   ?= target
# concurrency:requests pairs. matches what the report ran.
LEVELS  ?= 4:64,64:256
PROMPT  ?= 512
OUTPUT  ?= 256
RESULT  ?= bench/out/loadtest.json

# cheap reachability check first - a failed load test that was really a bad
# key or a dead tunnel wastes a lot of time before it says so.
ping:
	@test -n "$(KEY)" || { echo "usage: make ping KEY=<api key>   (or export API_KEY)"; exit 1; }
	@curl -fsS --max-time 20 $(URL)/models -H "Authorization: Bearer $(KEY)" \
	  | python3 -c "import json,sys; [print('  serving:',m['id']) for m in json.load(sys.stdin)['data']]" \
	  || { echo "  $(URL) not reachable, or the key was rejected"; exit 1; }

loadtest: ping
	@python3 -c "import aiohttp" 2>/dev/null || { echo "pip install aiohttp"; exit 1; }
	@echo "==> $(LEVELS) against $(URL)  ($(PROMPT) in / $(OUTPUT) out)"
	@echo "    tail percentiles include your own network path - compare shapes,"
	@echo "    not absolute TTFT, against numbers taken on the box."
	python3 bench/benchmark.py \
	  --base-url $(URL) --api-key $(KEY) --model $(MODEL) \
	  --config-name loadtest \
	  --levels "$(LEVELS)" \
	  --prompt-tokens $(PROMPT) --max-tokens $(OUTPUT) \
	  --out $(RESULT)
	@echo "==> $(RESULT)"
