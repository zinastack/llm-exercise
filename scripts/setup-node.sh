#!/usr/bin/env bash
# Brev startup script. Idempotent.
set -euo pipefail
exec > >(tee -a /var/log/exercise-setup.log) 2>&1
echo "==> setup start $(date -Is)"

while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do sleep 5; done

if ! command -v docker >/dev/null; then
  echo "==> docker"; curl -fsSL https://get.docker.com | sh
fi

if ! docker info 2>/dev/null | grep -qi nvidia; then
  echo "==> nvidia container toolkit"
  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
    | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
  curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
    | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
    > /etc/apt/sources.list.d/nvidia-container-toolkit.list
  apt-get update -qq && apt-get install -y -qq nvidia-container-toolkit
  nvidia-ctk runtime configure --runtime=docker
  systemctl restart docker
fi

# not on the base image
apt-get install -y -qq make python3 python3-pip >/dev/null 2>&1 || true
pip3 install --quiet --break-system-packages aiohttp 2>/dev/null \
  || pip3 install --quiet aiohttp 2>/dev/null || true

# a2 instances ship local nvme unmounted. boot disk is 125GB and fp16 weights
# are 141GB, so the cache has to go here. ephemeral - lost on stop.
echo "==> local NVMe for the model cache"
if ! mountpoint -q /mnt/models; then
  DEV=$(lsblk -dno NAME,SIZE,TYPE | awk '$3=="disk" && $1 ~ /^nvme/ {print "/dev/"$1; exit}')
  if [ -n "$DEV" ]; then
    mkfs.ext4 -q -F -m 0 -E lazy_itable_init=0,lazy_journal_init=0 "$DEV"
    mkdir -p /mnt/models
    mount -o discard,defaults,noatime "$DEV" /mnt/models
    chown -R ubuntu:ubuntu /mnt/models
    echo "    mounted $DEV at /mnt/models"
  else
    echo "    WARNING: no NVMe found - boot disk may be too small for FP16 weights"
  fi
fi
mkdir -p /mnt/models/huggingface && chown -R ubuntu:ubuntu /mnt/models
df -h /mnt/models | tail -1

echo "==> topology"
nvidia-smi topo -m || true
nvidia-smi --query-gpu=index,name,memory.total,compute_cap --format=csv || true
df -h / | tail -1
echo "==> setup done $(date -Is)"
