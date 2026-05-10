#!/usr/bin/env bash
set -euo pipefail

# ---- config ----
# Single buildx context/endpoint that has both amd64 and arm64 nodes attached
BUILDER="${BUILDER:-native-multi}"

IMAGE_BASE="${IMAGE_BASE:-ghcr.io/mestre8d/bigcapital-docker}"
IMAGE_TAG="${IMAGE_TAG:-webapp}"              # e.g. webapp or server
VERSION_TAG="${VERSION_TAG:-latest}"          # e.g. latest, v1.2.3
DOCKERFILE="${DOCKERFILE:-./packages/webapp/Dockerfile}"
CONTEXT_DIR="${CONTEXT_DIR:-.}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"

# Final multi-arch image references
IMAGE_REF="${IMAGE_BASE}:${IMAGE_TAG}"
VERSION_REF="${IMAGE_BASE}:${VERSION_TAG}"

echo "Using builder: ${BUILDER}"
echo "Platforms: ${PLATFORMS}"
echo "Dockerfile: ${DOCKERFILE}"
echo "Context: ${CONTEXT_DIR}"

# Sanity check: confirm the builder context exists
docker buildx inspect "${BUILDER}" >/dev/null

echo "==> Building ${PLATFORMS} via builder '${BUILDER}' and pushing ${IMAGE_REF} / ${VERSION_REF}"
docker buildx build \
  --builder "${BUILDER}" \
  --platform "${PLATFORMS}" \
  --file "${DOCKERFILE}" \
  --tag "${IMAGE_REF}" \
  --tag "${VERSION_REF}" \
  --push \
  "${CONTEXT_DIR}"

echo "==> Inspecting manifest"
docker buildx imagetools inspect "${VERSION_REF}"

echo "Done."
echo "Pushed:"
echo "  ${IMAGE_REF}"
echo "  ${VERSION_REF}"
