# syntax=docker/dockerfile:1

ARG PYTHON_VERSION=3.12
FROM python:${PYTHON_VERSION}-slim-bookworm

ARG PYTHON_VERSION
ARG NUMPY_VERSION
ARG TORCH_VERSION
ARG TORCHAUDIO_VERSION
ARG TORCHVISION_VERSION
ARG TORCHCODEC_VERSION=none
ARG TRITON_VERSION
ARG CUDA_VERSION
ARG CUDA_TAG
ARG MODOFORGE_USE_CHINA_MIRRORS=0

LABEL org.opencontainers.image.title="ModoForge runtime base" \
      io.modoforge.python.version="${PYTHON_VERSION}" \
    io.modoforge.numpy.version="${NUMPY_VERSION}" \
      io.modoforge.torch.version="${TORCH_VERSION}" \
      io.modoforge.triton.version="${TRITON_VERSION}" \
      io.modoforge.cuda.version="${CUDA_VERSION}" \
      io.modoforge.cuda.tag="${CUDA_TAG}"

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_ROOT_USER_ACTION=ignore \
    MODOFORGE_BASE_PYTHON_VERSION=${PYTHON_VERSION} \
    MODOFORGE_BASE_NUMPY_VERSION=${NUMPY_VERSION} \
    MODOFORGE_BASE_TORCH_VERSION=${TORCH_VERSION} \
    MODOFORGE_BASE_TORCHAUDIO_VERSION=${TORCHAUDIO_VERSION} \
    MODOFORGE_BASE_TORCHVISION_VERSION=${TORCHVISION_VERSION} \
    MODOFORGE_BASE_TORCHCODEC_VERSION=${TORCHCODEC_VERSION} \
    MODOFORGE_BASE_TRITON_VERSION=${TRITON_VERSION} \
    MODOFORGE_BASE_CUDA_VERSION=${CUDA_VERSION} \
    MODOFORGE_BASE_CUDA_TAG=${CUDA_TAG}

# Install the complete compatible PyTorch family atomically. TorchCodec is
# omitted only when no release exists for the selected Torch family.
RUN --mount=type=bind,source=install.sh,target=/tmp/install.sh \
    /bin/sh /tmp/install.sh
