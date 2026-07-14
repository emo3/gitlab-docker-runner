#!/bin/sh
set -eu

run() {
  printf '\n$ %s\n' "$*"
  "$@"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: required command not found: $1" >&2
    exit 1
  }
}

for command_name in \
  aws bash curl dig docker gh git glab helm jq kubectl make pip python python3 \
  scp ssh terraform tofu unzip yq packer
do
  require_command "${command_name}"
done

run tofu version
run terraform version
run packer version
run python --version
run python3 --version
run pip --version
run aws --version
run kubectl version --client=true
run helm version --short
run docker --version
run jq --version
run yq --version
run git --version
run gh --version
run glab --version
run bash --version
