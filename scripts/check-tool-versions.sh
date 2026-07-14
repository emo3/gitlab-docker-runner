#!/bin/sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
VERSIONS_FILE="${PROJECT_ROOT}/config/upstream-tools.env"

if [ ! -f "${VERSIONS_FILE}" ]; then
  echo "ERROR: ${VERSIONS_FILE} was not found." >&2
  exit 1
fi

. "${VERSIONS_FILE}"

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

print_row() {
  name="$1"
  pinned="$2"
  latest="$3"

  if [ "${pinned}" = "${latest}" ]; then
    status="current"
  else
    status="update available"
  fi

  printf '%-10s pinned=%-10s latest=%-10s %s\n' "${name}" "${pinned}" "${latest}" "${status}"
}

opentofu_latest="$(latest_github_release opentofu/opentofu)"
packer_latest="$(latest_github_release hashicorp/packer)"
terraform_latest="$(latest_github_release hashicorp/terraform)"

print_row opentofu "${OPENTOFU_VERSION}" "${opentofu_latest}"
print_row packer "${PACKER_VERSION}" "${packer_latest}"
print_row terraform "${TERRAFORM_VERSION}" "${terraform_latest}"
