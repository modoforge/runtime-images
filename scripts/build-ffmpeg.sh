#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_BASE="${IMAGE_BASE:-ffmpeg}"
TAG="6.1.6"
PLATFORMS="${PLATFORMS:-linux/amd64}"
PUSH=0
DATE_TAG="${DATE_TAG:-}"
DRY_RUN="${DRY_RUN:-0}"

usage() {
  cat <<'EOF'
Usage: scripts/build-ffmpeg.sh [options]

Options:
  --image-base NAME  Image repository (default: ffmpeg).
  --platforms LIST   Target platforms (default: linux/amd64).
  --push             Push instead of loading into the local Docker store.
  --date-tag DATE    Also publish 6.1.6-YYYYMMDD.
  -h, --help         Show this help.
EOF
}

while (($#)); do
  case "$1" in
    --image-base) IMAGE_BASE="${2:?--image-base requires a value}"; shift 2 ;;
    --platforms) PLATFORMS="${2:?--platforms requires a value}"; shift 2 ;;
    --push) PUSH=1; shift ;;
    --date-tag) DATE_TAG="${2:?--date-tag requires a value}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 64 ;;
  esac
done

command -v docker >/dev/null || { echo "docker is required" >&2; exit 69; }
docker buildx version >/dev/null

output_args=(--load)
if ((PUSH)); then
  output_args=(--push)
elif [[ "$PLATFORMS" == *,* ]]; then
  echo "Cannot --load multiple platforms; use one --platforms value or --push" >&2
  exit 64
fi

tag_args=(--tag "${IMAGE_BASE}:${TAG}")
if [[ -n "$DATE_TAG" ]]; then
  tag_args+=(--tag "${IMAGE_BASE}:${TAG}-${DATE_TAG}")
fi

command=(docker buildx build
  --platform "$PLATFORMS"
  --file "${ROOT}/ffmpeg.dockerfile"
  "${tag_args[@]}"
  "${output_args[@]}"
  "$ROOT")

if [[ "$DRY_RUN" == "1" ]]; then
  printf ' +'; printf ' %q' "${command[@]}"; printf '\n'
else
  "${command[@]}"
fi
