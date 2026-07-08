#!/bin/sh
set -eu

run() {
  printf '\n$ %s\n' "$*"
  "$@"
}

run tofu version
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
