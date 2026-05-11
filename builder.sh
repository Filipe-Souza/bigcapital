#!/usr/bin/env bash
set -euo pipefail

# ---- config ----
# Single buildx context/endpoint that has both amd64 and arm64 nodes attached
BUILDER="${BUILDER:-native-multi}"

IMAGE_BASE="${IMAGE_BASE:-ghcr.io/mestre8d/bigcapital-docker}"
VERSION_TAG="${VERSION_TAG:-latest}"          # e.g. latest, v1.2.3
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"

# Targets to build. Each target is "<image-tag>:<dockerfile>:<context-dir>".
# Override by exporting TARGETS as a space-separated list, or pass target
# names as CLI args (e.g. `./builder.sh webapp mariadb`).
declare -A TARGET_DOCKERFILE=(
  [webapp]="./packages/webapp/Dockerfile"
  [server]="./packages/server/Dockerfile"
  [mariadb]="./docker/mariadb/Dockerfile"
  [redis]="./docker/redis/Dockerfile"
)
declare -A TARGET_CONTEXT=(
  [webapp]="."
  [server]="."
  [mariadb]="./docker/mariadb"
  [redis]="./docker/redis"
)

# Default set of targets if none are specified.
DEFAULT_TARGETS=("webapp")

# Allow legacy single-target invocation via env vars.
if [[ -n "${IMAGE_TAG:-}" || -n "${DOCKERFILE:-}" || -n "${CONTEXT_DIR:-}" ]]; then
  legacy_tag="${IMAGE_TAG:-webapp}"
  TARGET_DOCKERFILE[$legacy_tag]="${DOCKERFILE:-${TARGET_DOCKERFILE[$legacy_tag]:-}}"
  TARGET_CONTEXT[$legacy_tag]="${CONTEXT_DIR:-${TARGET_CONTEXT[$legacy_tag]:-.}}"
  selected_targets=("$legacy_tag")
elif [[ $# -gt 0 ]]; then
  selected_targets=("$@")
else
  selected_targets=("${DEFAULT_TARGETS[@]}")
fi

echo "Using builder: ${BUILDER}"
echo "Platforms: ${PLATFORMS}"
echo "Targets: ${selected_targets[*]}"

# Sanity check: confirm the builder context exists
docker buildx inspect "${BUILDER}" >/dev/null

build_target() {
  local image_tag="$1"
  local dockerfile="${TARGET_DOCKERFILE[$image_tag]:-}"
  local context_dir="${TARGET_CONTEXT[$image_tag]:-.}"

  if [[ -z "${dockerfile}" ]]; then
    echo "Unknown target '${image_tag}'. Known: ${!TARGET_DOCKERFILE[*]}" >&2
    exit 1
  fi

  local image_ref="${IMAGE_BASE}:${image_tag}"
  local version_ref="${IMAGE_BASE}:${image_tag}-${VERSION_TAG}"

  echo
  echo "==> [${image_tag}] Building ${PLATFORMS}"
  echo "    Dockerfile: ${dockerfile}"
  echo "    Context:    ${context_dir}"
  echo "    Pushing:    ${image_ref} and ${version_ref}"

  docker buildx build \
    --builder "${BUILDER}" \
    --platform "${PLATFORMS}" \
    --file "${dockerfile}" \
    --tag "${image_ref}" \
    --tag "${version_ref}" \
    --push \
    "${context_dir}"

  echo "==> [${image_tag}] Inspecting manifest"
  docker buildx imagetools inspect "${version_ref}"
}

for t in "${selected_targets[@]}"; do
  build_target "$t"
done

echo
echo "Done. Built targets: ${selected_targets[*]}"
