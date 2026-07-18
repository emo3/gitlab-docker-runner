#!/bin/sh
set -eu

DEFAULT_IMAGE="registry.192.168.86.50.nip.io/gitlab/gitlab-docker-runner:latest"
IMAGE="${1:-${GDR_IMAGE:-${DEFAULT_IMAGE}}}"

printf 'Pulling %s\n' "${IMAGE}"
docker pull "${IMAGE}"

printf 'Opening Bash in %s\n' "${IMAGE}"
exec docker run --rm -it \
  --workdir /workspace \
  --volume "${PWD}:/workspace" \
  "${IMAGE}" \
  /bin/bash
