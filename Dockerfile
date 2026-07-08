FROM cgr.dev/chainguard/wolfi-base AS tool-downloads

ARG TARGETARCH
ARG OPENTOFU_VERSION=1.12.3
ARG PACKER_VERSION=1.15.4

SHELL ["/bin/sh", "-euxo", "pipefail", "-c"]

RUN apk update && apk add --no-cache \
    ca-certificates-bundle \
    cosign \
    curl \
    gpg \
    gpg-agent \
    unzip

RUN case "${TARGETARCH:-$(uname -m)}" in \
      amd64|x86_64) export TOOL_ARCH=amd64 ;; \
      arm64|aarch64) export TOOL_ARCH=arm64 ;; \
      arm|armv7*) export TOOL_ARCH=arm ;; \
      386|i386|i686) export TOOL_ARCH=386 ;; \
      *) echo "Unsupported architecture: ${TARGETARCH:-$(uname -m)}" >&2; exit 1 ;; \
    esac; \
    mkdir -p /tmp/tools /out; \
    cd /tmp/tools; \
    curl -fsSLO "https://github.com/opentofu/opentofu/releases/download/v${OPENTOFU_VERSION}/tofu_${OPENTOFU_VERSION}_linux_${TOOL_ARCH}.zip"; \
    curl -fsSLO "https://github.com/opentofu/opentofu/releases/download/v${OPENTOFU_VERSION}/tofu_${OPENTOFU_VERSION}_SHA256SUMS"; \
    curl -fsSLO "https://github.com/opentofu/opentofu/releases/download/v${OPENTOFU_VERSION}/tofu_${OPENTOFU_VERSION}_SHA256SUMS.sig"; \
    curl -fsSLO "https://github.com/opentofu/opentofu/releases/download/v${OPENTOFU_VERSION}/tofu_${OPENTOFU_VERSION}_SHA256SUMS.pem"; \
    OPENTOFU_MINOR="$(printf '%s\n' "${OPENTOFU_VERSION}" | awk -F. '{print $1 "." $2}')"; \
    cosign verify-blob \
      --certificate-identity "https://github.com/opentofu/opentofu/.github/workflows/release.yml@refs/heads/v${OPENTOFU_MINOR}" \
      --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
      --certificate "tofu_${OPENTOFU_VERSION}_SHA256SUMS.pem" \
      --signature "tofu_${OPENTOFU_VERSION}_SHA256SUMS.sig" \
      "tofu_${OPENTOFU_VERSION}_SHA256SUMS"; \
    grep "tofu_${OPENTOFU_VERSION}_linux_${TOOL_ARCH}.zip" "tofu_${OPENTOFU_VERSION}_SHA256SUMS" | sha256sum -c -; \
    unzip -q "tofu_${OPENTOFU_VERSION}_linux_${TOOL_ARCH}.zip" tofu; \
    install -m 0755 tofu /out/tofu; \
    curl -fsSLO "https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_${TOOL_ARCH}.zip"; \
    curl -fsSLO "https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_SHA256SUMS"; \
    curl -fsSLO "https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_SHA256SUMS.sig"; \
    export GNUPGHOME=/tmp/tools/gnupg; \
    mkdir -p "${GNUPGHOME}"; \
    chmod 700 "${GNUPGHOME}"; \
    curl -fsSL "https://www.hashicorp.com/.well-known/pgp-key.txt" | gpg --import; \
    gpg --batch --verify "packer_${PACKER_VERSION}_SHA256SUMS.sig" "packer_${PACKER_VERSION}_SHA256SUMS"; \
    grep "packer_${PACKER_VERSION}_linux_${TOOL_ARCH}.zip" "packer_${PACKER_VERSION}_SHA256SUMS" | sha256sum -c -; \
    unzip -q "packer_${PACKER_VERSION}_linux_${TOOL_ARCH}.zip" packer; \
    install -m 0755 packer /out/packer

FROM cgr.dev/chainguard/wolfi-base

LABEL org.opencontainers.image.title="gdr Wolfi developer runner image" \
      org.opencontainers.image.description="Chainguard Wolfi-based GitLab runner image with OpenTofu, Packer, Python, AWS CLI, Kubernetes, Docker, and common developer tools."

ARG OPENTOFU_VERSION=1.12.3
ARG PACKER_VERSION=1.15.4

SHELL ["/bin/sh", "-euxo", "pipefail", "-c"]

RUN apk update && apk add --no-cache \
    aws-cli-2 \
    bash \
    ca-certificates-bundle \
    curl \
    docker-cli \
    gh \
    git \
    glab \
    helm \
    jq \
    kubectl \
    make \
    openssh-client \
    py3-pip \
    python-3.13 \
    unzip \
    yq

COPY --from=tool-downloads /out/tofu /usr/local/bin/tofu
COPY --from=tool-downloads /out/packer /usr/local/bin/packer
COPY scripts/verify-tools.sh /usr/local/bin/verify-tools.sh

RUN chmod 0755 /usr/local/bin/tofu /usr/local/bin/packer /usr/local/bin/verify-tools.sh; \
    /usr/local/bin/verify-tools.sh

ENV OPENTOFU_VERSION="${OPENTOFU_VERSION}" \
    PACKER_VERSION="${PACKER_VERSION}"

CMD ["/bin/sh"]
