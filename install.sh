#!/bin/sh
set -eu

readonly DEFAULT_PYTORCH_INDEX_BASE="https://download.pytorch.org/whl"
readonly CHINA_PYPI_INDEX_URL="https://pypi.tuna.tsinghua.edu.cn/simple"
readonly CHINA_PYTORCH_INDEX_BASE="https://mirrors.nju.edu.cn/pytorch/whl"
readonly CHINA_PYTORCH_FIND_LINKS_BASE="https://mirrors.aliyun.com/pytorch-wheels"

: "${TORCH_VERSION:?TORCH_VERSION is required}"
: "${NUMPY_VERSION:?NUMPY_VERSION is required}"
: "${TORCHAUDIO_VERSION:?TORCHAUDIO_VERSION is required}"
: "${TORCHVISION_VERSION:?TORCHVISION_VERSION is required}"
: "${TORCHCODEC_VERSION:=none}"
: "${TRITON_VERSION:?TRITON_VERSION is required (use none when omitted)}"
: "${CUDA_TAG:?CUDA_TAG is required}"

torchcodec_from_pypi=0
case "${CUDA_TAG}:${TORCHCODEC_VERSION}" in
    cpu:0.1.*) torchcodec_from_pypi=1 ;;
esac

install_pytorch() {
    set -- "$@" \
        "torch==${TORCH_VERSION}" \
        "torchaudio==${TORCHAUDIO_VERSION}" \
        "torchvision==${TORCHVISION_VERSION}"
    if [ "${TORCHCODEC_VERSION}" != "none" ] && [ "${torchcodec_from_pypi}" = 0 ]; then
        set -- "$@" "torchcodec==${TORCHCODEC_VERSION}"
    fi
    if [ "${TRITON_VERSION}" != "none" ]; then
        set -- "$@" "triton==${TRITON_VERSION}; platform_machine == 'x86_64'"
    fi
    python -m pip install "$@"
}

case "${MODOFORGE_USE_CHINA_MIRRORS:-0}" in
    1|true|TRUE|yes|YES)
        use_china_mirrors=1
        export PIP_INDEX_URL="${CHINA_PYPI_INDEX_URL}"
        pytorch_index_base="${CHINA_PYTORCH_INDEX_BASE}"
        ;;
    ''|0|false|FALSE|no|NO)
        use_china_mirrors=0
        pytorch_index_base="${DEFAULT_PYTORCH_INDEX_BASE}"
        ;;
    *)
        echo "error: MODOFORGE_USE_CHINA_MIRRORS must be a boolean value; got ${MODOFORGE_USE_CHINA_MIRRORS}" >&2
        exit 64
        ;;
esac

python -m pip install --upgrade pip wheel
# TorchVision requires NumPy without an upper bound. Install the matrix pin
# first so old Torch wheels do not accidentally resolve a NumPy 2.x ABI.
python -m pip install "numpy==${NUMPY_VERSION}"

pytorch_installed=0
if [ "${use_china_mirrors}" = 1 ]; then
    # Aliyun's flat PyTorch wheel collection does not publish Triton. Add the
    # mirrored Triton project page without exposing unrelated index candidates.
    if PIP_EXTRA_INDEX_URL= install_pytorch \
        --no-index \
        --no-deps \
        --find-links "${CHINA_PYTORCH_FIND_LINKS_BASE}/${CUDA_TAG}/" \
        --find-links "${CHINA_PYTORCH_INDEX_BASE}/${CUDA_TAG}/triton/"; then
        install_pytorch
        pytorch_installed=1
    else
        echo "info: PyTorch wheel mirror did not satisfy the request; falling back to ${pytorch_index_base}/${CUDA_TAG}" >&2
    fi
fi

if [ "${pytorch_installed}" = 0 ]; then
    if PIP_EXTRA_INDEX_URL= install_pytorch \
        --index-url "${pytorch_index_base}/${CUDA_TAG}"; then
        pytorch_installed=1
    elif [ "${pytorch_index_base}" != "${DEFAULT_PYTORCH_INDEX_BASE}" ]; then
        echo "info: PyTorch index did not satisfy the request; falling back to ${DEFAULT_PYTORCH_INDEX_BASE}/${CUDA_TAG}" >&2
        PIP_EXTRA_INDEX_URL= install_pytorch \
            --index-url "${DEFAULT_PYTORCH_INDEX_BASE}/${CUDA_TAG}"
        pytorch_installed=1
    fi
fi

[ "${pytorch_installed}" = 1 ]

# TorchCodec 0.1.x CPU wheels are published on PyPI but are not present in the
# PyTorch CPU index. Later CPU releases remain installed from that index.
if [ "${torchcodec_from_pypi}" = 1 ]; then
    python -m pip install --no-deps "torchcodec==${TORCHCODEC_VERSION}"
fi

python -m pip check
python - <<'PY'
import os

import numpy
import torch

assert numpy.__version__ == os.environ["NUMPY_VERSION"]
array = numpy.zeros(1, dtype=numpy.float32)
tensor = torch.from_numpy(array)
assert tensor.numpy()[0] == 0
PY
