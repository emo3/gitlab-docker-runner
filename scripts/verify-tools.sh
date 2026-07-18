#!/bin/sh
set -eu

RUNTIME_PACKAGES_FILE="${GDR_RUNTIME_PACKAGES_FILE:-/etc/gdr/apk-runtime-packages.txt}"
UPSTREAM_TOOLS_FILE="${GDR_UPSTREAM_TOOLS_FILE:-/etc/gdr/upstream-tools.env}"
UPSTREAM_TOOLS_MANIFEST="${GDR_UPSTREAM_TOOLS_MANIFEST:-/etc/gdr/upstream-tools.manifest}"

run() {
  printf '\n$ %s\n' "$*"
  "$@"
}

require_file() {
  [ -f "$1" ] || {
    echo "ERROR: required file not found: $1" >&2
    exit 1
  }
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: required command not found: $1" >&2
    exit 1
  }
}

require_file "${RUNTIME_PACKAGES_FILE}"
require_file "${UPSTREAM_TOOLS_FILE}"
require_file "${UPSTREAM_TOOLS_MANIFEST}"

# The package manifest is the source of truth for the final image. Verify each
# non-comment entry and its declared commands instead of maintaining a second
# package or command list here.
sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "${RUNTIME_PACKAGES_FILE}" |
while IFS= read -r package_name; do
  apk info -e "${package_name}" > /dev/null || {
    echo "ERROR: configured runtime package is not installed: ${package_name}" >&2
    exit 1
  }
done

sed -n 's/^[[:space:]]*[^#[:space:]][^#]*#[[:space:]]*verify:[[:space:]]*//p' "${RUNTIME_PACKAGES_FILE}" |
while IFS= read -r verify_command; do
  run sh -c "${verify_command}"
done

# The image build records the versions it resolved in this file. Source it so
# verification fails if a downloaded binary drifts from that build's version.
. "${UPSTREAM_TOOLS_FILE}"

require_version() {
  tool_name="$1"
  expected_version="$2"
  actual_version="$3"

  if [ "${actual_version}" != "${expected_version}" ]; then
    echo "ERROR: ${tool_name} version ${actual_version} does not match configured ${expected_version}" >&2
    exit 1
  fi
}

while IFS='|' read -r tool source version_var version_command version_prefix; do
  case "${tool}" in ''|'#'*) continue ;; esac
  require_command "${tool}"
  eval "expected_version=\${${version_var}:-}"
  [ -n "${expected_version}" ] || {
    echo "ERROR: ${version_var} is required in ${UPSTREAM_TOOLS_FILE}" >&2
    exit 1
  }
  printf '\n$ %s\n' "${version_command}"
  version_output="$(sh -c "${version_command}")"
  printf '%s\n' "${version_output}"
  actual_version="$(printf '%s\n' "${version_output}" | sed -n "s/^${version_prefix}//p" | head -n 1)"
  require_version "${tool}" "${expected_version}" "${actual_version}"
done < "${UPSTREAM_TOOLS_MANIFEST}"
