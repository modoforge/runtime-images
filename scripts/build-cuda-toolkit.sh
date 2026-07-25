#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MATRIX="${ROOT}/cuda-toolkit-matrix.json"
IMAGE_BASE="${IMAGE_BASE:-cuda-toolkit}"
REQUESTED_TAG="all"
SHA_TAG="${SHA_TAG:-}"
DRY_RUN="${DRY_RUN:-0}"

usage() {
  cat <<'EOF'
Usage: scripts/build-cuda-toolkit.sh [options]

Copies upstream CUDA toolkit manifests directly to the configured registry.
This operation always publishes registry tags and never creates local layers.

Options:
  --tag TAG          Copy one matrix tag (default: all).
  --image-base NAME  Destination image repository (default: cuda-toolkit).
  --sha-tag SHA      Also publish TAG-SHA.
  -h, --help         Show this help.
EOF
}

while (($#)); do
  case "$1" in
    --tag) REQUESTED_TAG="${2:?--tag requires a value}"; shift 2 ;;
    --image-base) IMAGE_BASE="${2:?--image-base requires a value}"; shift 2 ;;
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
  echo "Unknown CUDA toolkit image tag: $REQUESTED_TAG" >&2
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
  source="$(jq -r '.source' <<<"$row")"
  tag_args=(--tag "${IMAGE_BASE}:${tag}")
  if [[ -n "$SHA_TAG" ]]; then
    tag_args+=(--tag "${IMAGE_BASE}:${tag}-${SHA_TAG}")
  fi
  run docker buildx imagetools create "${tag_args[@]}" "$source"
done
