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
gitlab-registry.gitlab.svc.cluster.local:5000/$CI_PROJECT_PATH:$CI_COMMIT_SHORT_SHA
gitlab-registry.gitlab.svc.cluster.local:5000/$CI_PROJECT_PATH:latest
```

The CI job uses Docker-in-Docker. It connects to the `docker:dind` service at
`tcp://docker:2375` with TLS disabled for this local runner setup, so the
GitLab Runner must allow privileged Docker services from Kubernetes jobs. If the
job says it cannot connect to `/var/run/docker.sock`, confirm `.gitlab-ci.yml`
sets `DOCKER_HOST`. If it cannot connect to `tcp://docker:2375`, update the
runner configuration in `../gitlabr` so `[runners.kubernetes]` includes
`privileged = true`, redeploy the runner, or move this project to a runner that
already supports Docker builds.

The GitLab-provided `CI_REGISTRY` value points at
`registry.127.0.0.1.nip.io`, which does not work from inside job pods because
`127.0.0.1` is the pod itself. The pipeline logs in and pushes to the in-cluster
registry service instead:

```text
gitlab-registry.gitlab.svc.cluster.local:5000
```

## Runner smoke test

After the image is published, use it from a project that can access the `k8s`
runner:

```yaml
developer-image-smoke:
  image: gitlab-registry.gitlab.svc.cluster.local:5000/$CI_PROJECT_PATH:latest
  tags:
    - k8s
  script:
    - /usr/local/bin/verify-tools.sh
    - tofu version
    - packer version
    - python --version
    - aws --version
```
