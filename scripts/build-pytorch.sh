#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MATRIX="${ROOT}/pytorch-matrix.json"
IMAGE_BASE="${IMAGE_BASE:-runtime-base}"
REQUESTED_TAG="all"
PLATFORMS="${PLATFORMS:-}"
PUSH=0
SHA_TAG="${SHA_TAG:-}"
DRY_RUN="${DRY_RUN:-0}"

usage() {
  cat <<'EOF'
Usage: scripts/build-pytorch.sh [options]

Options:
  --tag TAG          Build one matrix tag (default: all).
  --image-base NAME  Image repository (default: runtime-base).
  --platforms LIST   Override matrix platforms.
  --push             Push instead of loading into the local Docker store.
  --sha-tag SHA      Also publish TAG-SHA.
  -h, --help         Show this help.
EOF
}

while (($#)); do
  case "$1" in
    --tag) REQUESTED_TAG="${2:?--tag requires a value}"; shift 2 ;;
    --image-base) IMAGE_BASE="${2:?--image-base requires a value}"; shift 2 ;;
    --platforms) PLATFORMS="${2:?--platforms requires a value}"; shift 2 ;;
    --push) PUSH=1; shift ;;
    --sha-tag) SHA_TAG="${2:?--sha-tag requires a value}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 64 ;;
  esac
done

command -v jq >/dev/null || { echo "jq is required" >&2; exit 69; }
command -v docker >/dev/null || { echo "docker is required" >&2; exit 69; }
docker buildx version >/dev/null

if [[ "$REQUESTED_TAG" != "all" ]] \
    && ! jq -e --arg tag "$REQUESTED_TAG" '.include[] | select(.tag == $tag)' "$MATRIX" >/dev/null; then
  echo "Unknown PyTorch image tag: $REQUESTED_TAG" >&2
  exit 64
fi

run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf ' +'; printf ' %q' "$@"; printf '\n'
  else
    "$@"
  fi
}

jq -c --arg requested "$REQUESTED_TAG" \
  '.include[] | select($requested == "all" or .tag == $requested)' "$MATRIX" |
while IFS= read -r row; do
  tag="$(jq -r '.tag' <<<"$row")"
  row_platforms="$(jq -r --arg tag "$tag" \
    '.platforms as $platforms | ($platforms["base-overrides"][$tag] // $platforms.default) | join(",")' \
    "$MATRIX")"
  if [[ -n "$PLATFORMS" ]]; then
    target_platforms="$PLATFORMS"
  elif ((PUSH)); then
    target_platforms="$row_platforms"
  else
    target_platforms="linux/amd64"
  fi

  output_args=(--load)
  if ((PUSH)); then
    output_args=(--push)
  elif [[ "$target_platforms" == *,* ]]; then
    echo "Cannot --load multiple platforms for ${tag}; use --platforms or --push" >&2
    exit 64
  fi

  tag_args=(--tag "${IMAGE_BASE}:${tag}")
  if [[ -n "$SHA_TAG" ]]; then
    tag_args+=(--tag "${IMAGE_BASE}:${tag}-${SHA_TAG}")
  fi

  run docker buildx build \
    --platform "$target_platforms" \
    --file "${ROOT}/runtime-base.dockerfile" \
    --build-arg "PYTHON_VERSION=$(jq -r '.python' <<<"$row")" \
    --build-arg "NUMPY_VERSION=$(jq -r '.numpy' <<<"$row")" \
    --build-arg "TORCH_VERSION=$(jq -r '.torch' <<<"$row")" \
    --build-arg "TORCHAUDIO_VERSION=$(jq -r '.torchaudio' <<<"$row")" \
    --build-arg "TORCHVISION_VERSION=$(jq -r '.torchvision' <<<"$row")" \
    --build-arg "TORCHCODEC_VERSION=$(jq -r '.torchcodec' <<<"$row")" \
    --build-arg "TRITON_VERSION=$(jq -r '.triton' <<<"$row")" \
    --build-arg "CUDA_VERSION=$(jq -r '.cuda_version' <<<"$row")" \
    --build-arg "CUDA_TAG=$(jq -r '.cuda_tag' <<<"$row")" \
    "${tag_args[@]}" \
    "${output_args[@]}" \
    "$ROOT"
done
