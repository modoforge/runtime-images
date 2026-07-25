#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MATRIX="${ROOT}/ffmpeg-pytorch-matrix.json"
PYTORCH_MATRIX="${ROOT}/pytorch-matrix.json"
IMAGE_BASE="${IMAGE_BASE:-runtime-base}"
FFMPEG_IMAGE="${FFMPEG_IMAGE:-ffmpeg}"
FFMPEG_TAG="${FFMPEG_TAG:-6.1.6}"
REQUESTED_TAG="all"
PLATFORMS="${PLATFORMS:-}"
PUSH=0
DATE_TAG="${DATE_TAG:-}"
DRY_RUN="${DRY_RUN:-0}"

usage() {
  cat <<'EOF'
Usage: scripts/build-ffmpeg-pytorch.sh [options]

Options:
  --tag TAG          Build one matrix tag (default: all).
  --image-base NAME  Image repository (default: runtime-base).
  --ffmpeg-image NAME FFmpeg image repository (default: ffmpeg).
  --ffmpeg-tag TAG   FFmpeg foundation tag (default: 6.1.6).
  --platforms LIST   Override parent PyTorch matrix platforms.
  --push             Push instead of loading into the local Docker store.
  --date-tag DATE    Also publish TAG-YYYYMMDD.
  -h, --help         Show this help.
EOF
}

while (($#)); do
  case "$1" in
    --tag) REQUESTED_TAG="${2:?--tag requires a value}"; shift 2 ;;
    --image-base) IMAGE_BASE="${2:?--image-base requires a value}"; shift 2 ;;
    --ffmpeg-image) FFMPEG_IMAGE="${2:?--ffmpeg-image requires a value}"; shift 2 ;;
    --ffmpeg-tag) FFMPEG_TAG="${2:?--ffmpeg-tag requires a value}"; shift 2 ;;
    --platforms) PLATFORMS="${2:?--platforms requires a value}"; shift 2 ;;
    --push) PUSH=1; shift ;;
    --date-tag) DATE_TAG="${2:?--date-tag requires a value}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 64 ;;
  esac
done

command -v jq >/dev/null || { echo "jq is required" >&2; exit 69; }
command -v docker >/dev/null || { echo "docker is required" >&2; exit 69; }
docker buildx version >/dev/null

if [[ "$REQUESTED_TAG" != "all" ]] \
    && ! jq -e --arg tag "$REQUESTED_TAG" '.include[] | select(.tag == $tag)' "$MATRIX" >/dev/null; then
  echo "Unknown FFmpeg-PyTorch image tag: $REQUESTED_TAG" >&2
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
  base_tag="$(jq -r '.base_tag' <<<"$row")"
  row_platforms="$(jq -r --arg tag "$base_tag" \
    '.platforms as $platforms | ($platforms["base-overrides"][$tag] // $platforms.default) | join(",")' \
    "$PYTORCH_MATRIX")"
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
  if [[ -n "$DATE_TAG" ]]; then
    tag_args+=(--tag "${IMAGE_BASE}:${tag}-${DATE_TAG}")
  fi

  run docker buildx build \
    --platform "$target_platforms" \
    --file "${ROOT}/runtime-base-ffmpeg.dockerfile" \
    --build-arg "BASE_IMAGE=${IMAGE_BASE}:${base_tag}" \
    --build-arg "FFMPEG_IMAGE=${FFMPEG_IMAGE}:${FFMPEG_TAG}" \
    --build-arg "LIBSNDFILE_PACKAGE_VERSION=$(jq -r '.libsndfile_package_version' <<<"$row")" \
    --build-arg "LIBSNDFILE_VERSION=$(jq -r '.libsndfile_version' <<<"$row")" \
    "${tag_args[@]}" \
    "${output_args[@]}" \
    "$ROOT"
done
