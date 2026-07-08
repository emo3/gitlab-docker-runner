# Chainguard Wolfi developer runner image

This directory builds a GitLab Runner job image for the sibling `../gitlabr`
runner. The image is based on the free Chainguard Wolfi image:

```text
cgr.dev/chainguard/wolfi-base
```

It is intended for cloud and infrastructure development jobs that need a
trusted base image plus common command-line tools.

## Tooling

The image installs these Wolfi/APK-managed tools where available:

- AWS CLI v2
- Bash
- Docker CLI
- Git
- GitHub CLI (`gh`)
- GitLab CLI (`glab`)
- Helm
- jq
- kubectl
- make
- OpenSSH client
- Python 3.13, pip, and venv support
- curl, unzip, and CA certificates
- yq

The image also installs these upstream release binaries after verification:

- OpenTofu `1.12.3`
- Packer `1.15.4`

OpenTofu is used instead of HashiCorp Terraform. There is intentionally no
`terraform` compatibility symlink; jobs should call `tofu`.

## Quick start

Make sure the local GitLab install is healthy:

```bash
cd $HOME/code/gitlabc
bash scripts/check_status.sh
```

Open GitLab:

```text
https://gitlab.127.0.0.1.nip.io/users/sign_in
```

Build the image locally:

```bash
cd $HOME/code/gdr
docker build -t gdr-runner:dev .
```

Verify the installed tools:

```bash
docker run --rm gdr-runner:dev /usr/local/bin/verify-tools.sh
```

Open a shell:

```bash
docker run --rm -it gdr-runner:dev /bin/sh
docker run --rm -it gdr-runner:dev /bin/bash
```

## Version updates

The Dockerfile exposes build arguments for the upstream binaries:

```bash
docker build \
  --build-arg OPENTOFU_VERSION=1.12.3 \
  --build-arg PACKER_VERSION=1.15.4 \
  -t gdr-runner:dev .
```

Before changing these defaults, confirm the release is stable and update the
README, `.gitlab-ci.yml`, and `Dockerfile` together.

Verification happens during the build:

- OpenTofu downloads the release zip, SHA256SUMS, certificate, and signature
  from GitHub Releases, verifies the checksum file with Cosign, then verifies
  the zip checksum.
- Packer downloads the release zip, SHA256SUMS, and signature from
  `releases.hashicorp.com`, verifies the checksum file with HashiCorp's GPG
  key, then verifies the zip checksum.

## GitLab CI

The pipeline builds the image, runs `/usr/local/bin/verify-tools.sh` inside the
built image, and only then pushes both tags:

```text
$CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA
$CI_REGISTRY_IMAGE:latest
```

The CI job uses Docker-in-Docker, so the GitLab Runner must allow Docker builds
from Kubernetes jobs. If the job cannot connect to the Docker daemon, update
the runner configuration in `../gitlabr` to support privileged Docker builds or
move this project to a runner that already supports them.

## Runner smoke test

After the image is published, use it from a project that can access the `k8s`
runner:

```yaml
developer-image-smoke:
  image: $CI_REGISTRY_IMAGE:latest
  tags:
    - k8s
  script:
    - /usr/local/bin/verify-tools.sh
    - tofu version
    - packer version
    - python --version
    - aws --version
```
