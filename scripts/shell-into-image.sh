#!/bin/sh
set -eu

DEFAULT_IMAGE="registry.127.0.0.1.nip.io/gitlab/gitlab-docker-runner:latest"
IMAGE="${1:-${GDR_IMAGE:-${DEFAULT_IMAGE}}}"

printf 'Pulling %s\n' "${IMAGE}"
docker pull "${IMAGE}"

printf 'Opening Bash in %s\n' "${IMAGE}"
exec docker run --rm -it \
  --workdir /workspace \
  --volume "${PWD}:/workspace" \
  "${IMAGE}" \
  /bin/bash
