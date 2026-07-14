# Chainguard Wolfi developer runner image

This directory builds a GitLab Runner job image for the sibling `../gitlabr`
runner. The image is based on the free Chainguard Wolfi image:

```text
cgr.dev/chainguard/wolfi-base
```

It is intended for cloud and infrastructure development jobs that need a
trusted base image plus common command-line tools.

## Tooling

The image installs these Wolfi/APK-managed tools listed in:

[apk-runtime-packages.txt](config/apk-runtime-packages.txt)

The image also installs these upstream release binaries listed in after verification:

[upstream-tools.env](config/upstream-tools.env)

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
cd $HOME/code/gitlab-docker-runner
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

## Package and version updates

Packages that users and CI jobs need in the final image live in:

```text
config/apk-runtime-packages.txt
```

Packages needed only while the Dockerfile builds the image, such as download,
archive, or signature-verification tools, live in:

```text
config/apk-build-packages.txt
```

Use this rule: if a CI job runs the command, add it to the runtime file. If
only the Dockerfile needs it to construct the image, add it to the build file.
A package needed in both stages must appear in both files because Docker stages
do not share installed packages. After changing either file, rebuild and run
the verifier.

Pinned upstream binary versions live in:

```text
config/upstream-tools.env
```

The Dockerfile reads those pins directly. This file is the single source of
truth for upstream tool versions:

```bash
docker build -t gdr-runner:dev .
```

Add a version variable to `config/upstream-tools.env` when adding another
upstream binary installer. The build fails early when a required pin is empty
or missing.

Check pinned versions against latest stable upstream releases:

```bash
scripts/check-tool-versions.sh
```

Update only `config/upstream-tools.env` to the latest stable upstream versions:

```bash
scripts/update-tool-versions.sh --write
```

After changing packages or versions, rebuild and run
`/usr/local/bin/verify-tools.sh`.

The Wolfi base image is pinned to a multi-platform digest through
`WOLFI_BASE` in the Dockerfile. Renovate is configured in `renovate.json` to
check that digest and the three upstream tool pins weekly. APK package names
remain unversioned so builds receive current security and compatibility fixes
from the Wolfi repositories. Consequently, the base filesystem is
reproducible, but the installed APK package set can still change over time.

Verification happens during the build:

- OpenTofu downloads the release zip, SHA256SUMS, certificate, and signature
  from GitHub Releases, verifies the checksum file with Cosign, then verifies
  the zip checksum.
- Packer and Terraform download release zips, SHA256SUMS, and signatures from
  `releases.hashicorp.com`, verify checksum files with HashiCorp's GPG key,
  then verify each zip checksum.

## GitLab CI

The pipeline uses the `local` Docker executor and does not require host Docker
or Docker-in-Docker for the image build. It has three stages:

- `build`: builds and pushes the commit-tagged image with BuildKit rootless.
- `verify`: starts the commit-tagged image as the GitLab job image and runs
  `/usr/local/bin/verify-tools.sh`.
- `promote`: copies the verified commit tag to `latest` with `crane`.

The build stage pushes through the in-cluster registry service that is reachable
from runner job pods:

```text
gitlab-registry.gitlab.svc.cluster.local:5000/$CI_PROJECT_PATH:$CI_COMMIT_SHORT_SHA
```

The promote stage updates:

```text
gitlab-registry.gitlab.svc.cluster.local:5000/$CI_PROJECT_PATH:latest
```

Pull the latest image and open Bash with the current directory mounted at
`/workspace`:

```bash
scripts/shell-into-image.sh
```

Pass another image or commit tag as the first argument when needed:

```bash
scripts/shell-into-image.sh \
  registry.127.0.0.1.nip.io/gitlab/gitlab-docker-runner:COMMIT_SHA
```

If the registry requires authentication, run `docker login
registry.127.0.0.1.nip.io` first.

BuildKit rootless builds from the repository `Dockerfile` with
`buildctl-daemonless.sh`, using registry cache at
`gitlab-registry.gitlab.svc.cluster.local:5000/$CI_PROJECT_PATH:buildkit-cache`.

The GitLab registry advertises `$CI_REGISTRY` as
`registry.127.0.0.1.nip.io`. That works from the host Docker daemon, but inside
runner job pods `127.0.0.1` points at the pod itself. The pipeline therefore
pushes and promotes with `CI_REGISTRY_INTERNAL`, while the verify job uses
GitLab's normal `$CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA` name so the runner can
pull the image through its configured registry path.

## Runner smoke test

After the image is published, use it from a project that can access the `local`
runner:

```yaml
developer-image-smoke:
  image: registry.127.0.0.1.nip.io/gitlab/gitlab-docker-runner:latest
  tags:
    - local
  script:
    - /usr/local/bin/verify-tools.sh
    - tofu version
    - terraform version
    - packer version
    - python --version
    - aws --version
```
