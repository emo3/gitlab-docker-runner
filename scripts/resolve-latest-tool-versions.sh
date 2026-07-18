#!/bin/sh
set -eu

latest_github_release() {
  repo="$1"
  body_file="$(mktemp)"
  trap 'rm -f "${body_file}"' EXIT

  curl -fsSL \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${repo}/releases/latest" \
    -o "${body_file}"

  tag="$(sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${body_file}" | sed 's/^v//' | head -n 1)"
  rm -f "${body_file}"
  trap - EXIT

  if [ -z "${tag}" ]; then
    echo "ERROR: Could not find latest release tag for ${repo}." >&2
    exit 1
  fi

  printf '%s\n' "${tag}"
}

opentofu_version="$(latest_github_release opentofu/opentofu)"
packer_version="$(latest_github_release hashicorp/packer)"
terraform_version="$(latest_github_release hashicorp/terraform)"

printf 'OPENTOFU_VERSION=%s\n' "${opentofu_version}"
printf 'PACKER_VERSION=%s\n' "${packer_version}"
printf 'TERRAFORM_VERSION=%s\n' "${terraform_version}"
