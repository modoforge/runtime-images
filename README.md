# ModoForge runtime base images

This repository owns only the reusable OCI base-image sources consumed by
ModoForge runtime images:

- `runtime-base.dockerfile` builds the Python/PyTorch family base.
- `install.sh` installs the selected pinned Python packages.
- `ffmpeg.dockerfile` builds the checksum-pinned FFmpeg foundation.
- `runtime-base-ffmpeg.dockerfile` adds FFmpeg and its runtime libraries to a PyTorch base.
- `pytorch-matrix.json` declares the published PyTorch base variants and platform policy.
- `ffmpeg-pytorch-matrix.json` declares the PyTorch parents that receive the fixed FFmpeg 6.1.6 layer.
- `cuda-toolkit-matrix.json` declares the exact upstream CUDA toolkit images published under ModoForge tags.

CUDA toolkit images are copied registry-to-registry with `docker buildx
imagetools create`; they are not rebuilt, unpacked, or given extra layers.

The FFmpeg version and source checksum are fixed in `ffmpeg.dockerfile`; FFmpeg
is not a version matrix.

Published repositories are separated by image responsibility:

- `ghcr.io/modoforge/runtime-base:<torch-tag>` for PyTorch and FFmpeg-PyTorch bases.
- `ghcr.io/modoforge/ffmpeg:6.1.6` for the standalone FFmpeg foundation.
- `ghcr.io/modoforge/cuda-toolkit:<version>-ubuntu22.04` for mirrored CUDA toolkits.

Runtime selection, runtime compatibility mappings, runtime Dockerfiles, and runtime
installation logic remain in the main ModoForge repository. The main
repository uses the published base-image tags through each runtime Dockerfile's
`BASE_IMAGE` argument.

The build context must be this repository root because `runtime-base.dockerfile`
bind-mounts the adjacent `install.sh` during the build.

## Local builds and pushes

Four scripts provide one entry point per image family:

- `scripts/build-pytorch.sh`
- `scripts/build-ffmpeg.sh`
- `scripts/build-ffmpeg-pytorch.sh`
- `scripts/build-cuda-toolkit.sh`

Use the Makefile for common operations:

```shell
make pytorch TAG=torch2.8.0-py3.10-cu128
make ffmpeg
make ffmpeg-pytorch TAG=torch2.8.0-py3.10-cu128-ffmpeg6.1.6
make push-pytorch TAG=torch2.8.0-py3.10-cu128
make push SHA_TAG="$(git rev-parse HEAD)"
```

Local Docker builds default to `linux/amd64` and load the result into the local
Docker store. Set `PLATFORMS` to select another single local platform. Push
targets preserve matrix platform policy; FFmpeg push defaults to both
`linux/amd64` and `linux/arm64`.

CUDA toolkit images are different: `build-cuda-toolkit.sh` always copies the
upstream registry manifest directly to `PUSH_CUDA_TOOLKIT_IMAGE`. It never
builds or loads a local image, so both `make cuda-toolkit` and
`make push-cuda-toolkit` are publishing operations.

## CI

Publishing is split into four top-level workflows:

- `.github/workflows/publish-pytorch.yml`
- `.github/workflows/publish-ffmpeg.yml`
- `.github/workflows/publish-ffmpeg-pytorch.yml`
- `.github/workflows/publish-cuda-toolkit.yml`

All four publishing workflows are manual-only (`workflow_dispatch`). Commits to
Dockerfiles, scripts, catalogs, or workflows never publish an image. Those
changes remain release candidates until a maintainer explicitly selects a Git
ref in GitHub Actions and starts the corresponding image-family workflow.

PyTorch, FFmpeg-PyTorch, and CUDA toolkit workflows expand their catalog into
one independently named job per published image tag, with isolated concurrency
keys and `fail-fast: false`. FFmpeg has one fixed-version publish job.

Manual PyTorch, FFmpeg-PyTorch, and CUDA toolkit runs accept one exact image
tag or `all`. The FFmpeg-PyTorch workflow consumes already-published FFmpeg and
PyTorch parent tags; it does not implicitly rebuild either parent family.
