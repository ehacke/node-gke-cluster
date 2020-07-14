#!/usr/bin/env bash
IMAGE_SCOPE=ehacke
IMAGE_NAME=redis
VERSION=5.0

docker pull "${IMAGE_NAME}:${VERSION}"
docker build -t "${IMAGE_SCOPE}/${IMAGE_NAME}:latest" -t "${IMAGE_SCOPE}/${IMAGE_NAME}:${VERSION}" .
docker push "${IMAGE_SCOPE}/${IMAGE_NAME}:latest"
docker push "${IMAGE_SCOPE}/${IMAGE_NAME}:${VERSION}"
