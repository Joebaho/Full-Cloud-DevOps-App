#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AWS_REGION="${AWS_REGION:-us-west-2}"
TF_DIR="$ROOT_DIR/infrastructure/terraform/ecr"

bash "$ROOT_DIR/scripts/terraform_init.sh" "$TF_DIR"

pushd "$TF_DIR" >/dev/null

declare -A repos=(
  ["aws_ecr_repository.auth"]="auth-service"
  ["aws_ecr_repository.cart"]="cart-service"
  ["aws_ecr_repository.payment"]="payment-service"
)

for resource in "${!repos[@]}"; do
  repo_name="${repos[$resource]}"

  if ! terraform state show "$resource" >/dev/null 2>&1; then
    if aws ecr describe-repositories --repository-names "$repo_name" --region "$AWS_REGION" >/dev/null 2>&1; then
      terraform import "$resource" "$repo_name"
    fi
  fi
done

terraform apply -auto-approve -var="region=$AWS_REGION"

popd >/dev/null
