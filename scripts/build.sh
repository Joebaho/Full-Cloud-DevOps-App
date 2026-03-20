#!/bin/bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-west-2}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
ACCOUNT_ID="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}"
REGISTRY="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$REGISTRY"

for service in auth cart payment; do
  image_name="${service}-service"
  docker build -t "$image_name:$IMAGE_TAG" "./services/$service"
  docker tag "$image_name:$IMAGE_TAG" "$REGISTRY/$image_name:$IMAGE_TAG"
  docker tag "$image_name:$IMAGE_TAG" "$REGISTRY/$image_name:latest"
  docker push "$REGISTRY/$image_name:$IMAGE_TAG"
  docker push "$REGISTRY/$image_name:latest"
done
