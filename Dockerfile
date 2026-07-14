ARG WOLFI_BASE=cgr.dev/chainguard/wolfi-base@sha256:02dab76bd852a70556b5b2002195c8a5fdab77d323c433bf6642aab080489795

FROM ${WOLFI_BASE} AS tool-downloads

ARG TARGETARCH

SHELL ["/bin/sh", "-euxo", "pipefail", "-c"]

COPY config/apk-build-packages.txt /tmp/apk-build-packages.txt
COPY config/upstream-tools.env /tmp/upstream-tools.env

RUN apk update; \
    apk add --no-cache $(sed -e 's/#.*//' -e '/^[[:space:]]*$/d' /tmp/apk-build-packages.txt)

RUN . /tmp/upstream-tools.env; \
    : "${OPENTOFU_VERSION:?OPENTOFU_VERSION is required in config/upstream-tools.env}"; \
    : "${PACKER_VERSION:?PACKER_VERSION is required in config/upstream-tools.env}"; \
    : "${TERRAFORM_VERSION:?TERRAFORM_VERSION is required in config/upstream-tools.env}"; \
    validate_version() { \
      case "$2" in \
        *[!0-9.]*|.*|*..*|*.) echo "Invalid $1: $2 (expected X.Y.Z)" >&2; exit 1 ;; \
      esac; \
      [ "$(printf '%s' "$2" | awk -F. '{print NF}')" -eq 3 ] || { echo "Invalid $1: $2 (expected X.Y.Z)" >&2; exit 1; }; \
    }; \
    validate_version OPENTOFU_VERSION "${OPENTOFU_VERSION}"; \
    validate_version PACKER_VERSION "${PACKER_VERSION}"; \
    validate_version TERRAFORM_VERSION "${TERRAFORM_VERSION}"; \
    case "${TARGETARCH:-$(uname -m)}" in \
      amd64|x86_64) TOOL_ARCH=amd64 ;; \
      arm64|aarch64) TOOL_ARCH=arm64 ;; \
      arm|armv7*) TOOL_ARCH=arm ;; \
      386|i386|i686) TOOL_ARCH=386 ;; \
      *) echo "Unsupported architecture: ${TARGETARCH:-$(uname -m)}" >&2; exit 1 ;; \
    esac; \
    install_opentofu() { \
      version="$1"; \
      arch="$2"; \
      curl -fsSLO "https://github.com/opentofu/opentofu/releases/download/v${version}/tofu_${version}_linux_${arch}.zip"; \
      curl -fsSLO "https://github.com/opentofu/opentofu/releases/download/v${version}/tofu_${version}_SHA256SUMS"; \
      curl -fsSLO "https://github.com/opentofu/opentofu/releases/download/v${version}/tofu_${version}_SHA256SUMS.sig"; \
      curl -fsSLO "https://github.com/opentofu/opentofu/releases/download/v${version}/tofu_${version}_SHA256SUMS.pem"; \
      minor="$(printf '%s\n' "${version}" | awk -F. '{print $1 "." $2}')"; \
      cosign verify-blob \
        --certificate-identity "https://github.com/opentofu/opentofu/.github/workflows/release.yml@refs/heads/v${minor}" \
        --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
        --certificate "tofu_${version}_SHA256SUMS.pem" \
        --signature "tofu_${version}_SHA256SUMS.sig" \
        "tofu_${version}_SHA256SUMS"; \
      grep "tofu_${version}_linux_${arch}.zip" "tofu_${version}_SHA256SUMS" | sha256sum -c -; \
      unzip -q "tofu_${version}_linux_${arch}.zip" tofu; \
      install -m 0755 tofu /out/tofu; \
      rm -f tofu tofu_${version}_*; \
    }; \
    install_hashicorp_tool() { \
      tool="$1"; \
      version="$2"; \
      arch="$3"; \
      curl -fsSLO "https://releases.hashicorp.com/${tool}/${version}/${tool}_${version}_linux_${arch}.zip"; \
      curl -fsSLO "https://releases.hashicorp.com/${tool}/${version}/${tool}_${version}_SHA256SUMS"; \
      curl -fsSLO "https://releases.hashicorp.com/${tool}/${version}/${tool}_${version}_SHA256SUMS.sig"; \
      gpg --batch --verify "${tool}_${version}_SHA256SUMS.sig" "${tool}_${version}_SHA256SUMS"; \
      grep "${tool}_${version}_linux_${arch}.zip" "${tool}_${version}_SHA256SUMS" | sha256sum -c -; \
      unzip -q "${tool}_${version}_linux_${arch}.zip" "${tool}"; \
      install -m 0755 "${tool}" "/out/${tool}"; \
      rm -f "${tool}" "${tool}_${version}_"*; \
    }; \
    mkdir -p /tmp/tools /out; \
    cd /tmp/tools; \
    export GNUPGHOME=/tmp/tools/gnupg; \
    mkdir -p "${GNUPGHOME}"; \
    chmod 700 "${GNUPGHOME}"; \
    curl -fsSL "https://www.hashicorp.com/.well-known/pgp-key.txt" | gpg --import; \
    install_opentofu "${OPENTOFU_VERSION}" "${TOOL_ARCH}"; \
    install_hashicorp_tool packer "${PACKER_VERSION}" "${TOOL_ARCH}"; \
    install_hashicorp_tool terraform "${TERRAFORM_VERSION}" "${TOOL_ARCH}"; \
    printf 'OPENTOFU_VERSION=%s\nPACKER_VERSION=%s\nTERRAFORM_VERSION=%s\n' \
      "${OPENTOFU_VERSION}" "${PACKER_VERSION}" "${TERRAFORM_VERSION}" > /out/upstream-tools.env

FROM ${WOLFI_BASE}

LABEL org.opencontainers.image.title="gdr Wolfi developer runner image" \
      org.opencontainers.image.description="Chainguard Wolfi-based GitLab runner image with OpenTofu, Terraform, Packer, Python, AWS CLI, Kubernetes, Docker, and common developer tools."

SHELL ["/bin/sh", "-euxo", "pipefail", "-c"]

COPY config/apk-runtime-packages.txt /tmp/apk-runtime-packages.txt

RUN apk update; \
    apk add --no-cache $(sed -e 's/#.*//' -e '/^[[:space:]]*$/d' /tmp/apk-runtime-packages.txt); \
    mkdir -p /etc/gdr; \
    rm -f /tmp/apk-runtime-packages.txt

COPY --from=tool-downloads /out/tofu /usr/local/bin/tofu
COPY --from=tool-downloads /out/packer /usr/local/bin/packer
COPY --from=tool-downloads /out/terraform /usr/local/bin/terraform
COPY --from=tool-downloads /out/upstream-tools.env /etc/gdr/upstream-tools.env
COPY scripts/verify-tools.sh /usr/local/bin/verify-tools.sh

RUN chmod 0755 /usr/local/bin/tofu /usr/local/bin/packer /usr/local/bin/terraform /usr/local/bin/verify-tools.sh; \
    /usr/local/bin/verify-tools.sh

CMD ["/bin/sh"]
