#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${1}" ]] || [[ -z "${2}" ]]; then
  echo "Usage: $0 DOCKER_IMAGE_NAME OUTPUT_PATH"
  exit 2
fi

workdir=$(mktemp -d)
container_id=$(docker create "${1}")
logdir="${2}/${1}"
[ ! -d "$logdir" ] && mkdir -p "$logdir"

docker export "$container_id" | tar xf - -C "$workdir"
sudo clamscan -r --infected "$workdir" 2>&1 | tee "$logdir/clamav.log"
sudo rm -rf "$workdir"
