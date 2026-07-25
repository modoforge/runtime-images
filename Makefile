SHELL := /bin/bash
.DEFAULT_GOAL := help

IMAGE_BASE ?= runtime-base
PUSH_IMAGE_BASE ?= ghcr.io/modoforge/runtime-base
FFMPEG_IMAGE ?= ffmpeg
PUSH_FFMPEG_IMAGE ?= ghcr.io/modoforge/ffmpeg
PUSH_CUDA_TOOLKIT_IMAGE ?= ghcr.io/modoforge/cuda-toolkit
TAG ?= all
PLATFORMS ?= linux/amd64
FFMPEG_PUSH_PLATFORMS ?= linux/amd64,linux/arm64
SHA_TAG ?=

SHA_TAG_ARG = $(if $(SHA_TAG),--sha-tag $(SHA_TAG),)
TAG_ARG = --tag $(TAG)

.PHONY: help all pytorch ffmpeg ffmpeg-pytorch cuda-toolkit \
        push push-pytorch push-ffmpeg push-ffmpeg-pytorch push-cuda-toolkit

help:
	@printf '%s\n' \
	  'Runtime base image targets:' \
	  '  make pytorch             Build PyTorch image(s) locally' \
	  '  make ffmpeg             Build FFmpeg locally' \
	  '  make ffmpeg-pytorch     Build FFmpeg-PyTorch image(s) locally' \
	  '  make cuda-toolkit       Copy CUDA toolkit manifest(s) to PUSH_CUDA_TOOLKIT_IMAGE' \
	  '  make all                Build all local image families; CUDA copy excluded' \
	  '  make push               Push/copy all four image families' \
	  '  make push-pytorch       Push PyTorch image(s)' \
	  '  make push-ffmpeg        Push FFmpeg' \
	  '  make push-ffmpeg-pytorch Push FFmpeg-PyTorch image(s)' \
	  '  make push-cuda-toolkit  Copy CUDA toolkit manifest(s)' \
	  '' \
	  'Variables:' \
	  '  TAG=all|<exact-tag>                 Select a matrix row' \
	  '  IMAGE_BASE=runtime-base             Local/destination repository' \
	  '  PUSH_IMAGE_BASE=ghcr.io/modoforge/runtime-base' \
	  '  FFMPEG_IMAGE=ffmpeg' \
	  '  PUSH_FFMPEG_IMAGE=ghcr.io/modoforge/ffmpeg' \
	  '  PUSH_CUDA_TOOLKIT_IMAGE=ghcr.io/modoforge/cuda-toolkit' \
	  '  PLATFORMS=linux/amd64                Local target platform' \
	  '  FFMPEG_PUSH_PLATFORMS=linux/amd64,linux/arm64' \
	  '  SHA_TAG=<git-sha>                    Add immutable TAG-SHA tags'

all:
	$(MAKE) ffmpeg
	$(MAKE) pytorch TAG=all
	$(MAKE) ffmpeg-pytorch TAG=all

pytorch:
	IMAGE_BASE="$(IMAGE_BASE)" scripts/build-pytorch.sh $(TAG_ARG) --platforms "$(PLATFORMS)" $(SHA_TAG_ARG)

ffmpeg:
	IMAGE_BASE="$(FFMPEG_IMAGE)" scripts/build-ffmpeg.sh --platforms "$(PLATFORMS)" $(SHA_TAG_ARG)

ffmpeg-pytorch:
	IMAGE_BASE="$(IMAGE_BASE)" FFMPEG_IMAGE="$(FFMPEG_IMAGE)" scripts/build-ffmpeg-pytorch.sh $(TAG_ARG) --platforms "$(PLATFORMS)" $(SHA_TAG_ARG)

# CUDA toolkit images are registry manifest copies, so even this non-prefixed
# target publishes to PUSH_CUDA_TOOLKIT_IMAGE and never creates a local image.
cuda-toolkit:
	IMAGE_BASE="$(PUSH_CUDA_TOOLKIT_IMAGE)" scripts/build-cuda-toolkit.sh $(TAG_ARG) $(SHA_TAG_ARG)

push:
	$(MAKE) push-ffmpeg
	$(MAKE) push-pytorch TAG=all
	$(MAKE) push-ffmpeg-pytorch TAG=all
	$(MAKE) push-cuda-toolkit TAG=all

push-pytorch:
	IMAGE_BASE="$(PUSH_IMAGE_BASE)" scripts/build-pytorch.sh $(TAG_ARG) --push $(SHA_TAG_ARG)

push-ffmpeg:
	IMAGE_BASE="$(PUSH_FFMPEG_IMAGE)" scripts/build-ffmpeg.sh --platforms "$(FFMPEG_PUSH_PLATFORMS)" --push $(SHA_TAG_ARG)

push-ffmpeg-pytorch:
	IMAGE_BASE="$(PUSH_IMAGE_BASE)" FFMPEG_IMAGE="$(PUSH_FFMPEG_IMAGE)" scripts/build-ffmpeg-pytorch.sh $(TAG_ARG) --push $(SHA_TAG_ARG)

push-cuda-toolkit: cuda-toolkit
