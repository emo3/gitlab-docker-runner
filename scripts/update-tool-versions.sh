#!/bin/sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
VERSIONS_FILE="${PROJECT_ROOT}/config/upstream-tools.env"

usage() {
  cat <<'EOF'
Usage: scripts/update-tool-versions.sh [--write]

Without --write, print the latest stable upstream versions.
With --write, update config/upstream-tools.env only.
EOF
}

case "${1:-}" in
  "")
    WRITE=false
    ;;
  --write)
    WRITE=true
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac

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

opentofu_latest="$(latest_github_release opentofu/opentofu)"
packer_latest="$(latest_github_release hashicorp/packer)"
terraform_latest="$(latest_github_release hashicorp/terraform)"

if [ "${WRITE}" = "false" ]; then
  printf 'OPENTOFU_VERSION=%s\n' "${opentofu_latest}"
  printf 'PACKER_VERSION=%s\n' "${packer_latest}"
  printf 'TERRAFORM_VERSION=%s\n' "${terraform_latest}"
  exit 0
fi

tmp_file="${VERSIONS_FILE}.tmp"
{
  printf 'OPENTOFU_VERSION=%s\n' "${opentofu_latest}"
  printf 'PACKER_VERSION=%s\n' "${packer_latest}"
  printf 'TERRAFORM_VERSION=%s\n' "${terraform_latest}"
} > "${tmp_file}"

mv "${tmp_file}" "${VERSIONS_FILE}"
echo "Updated ${VERSIONS_FILE}"
