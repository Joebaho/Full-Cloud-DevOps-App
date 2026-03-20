#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AWS_REGION="${AWS_REGION:-us-west-2}"
ZONE_NAME="${ZONE_NAME:-example.com}"
MANAGE_ROUTE53="${MANAGE_ROUTE53:-false}"

tf_init() {
  bash "$ROOT_DIR/scripts/terraform_init.sh" "$1"
}

echo "Starting destroy process in $ROOT_DIR"

if command -v helm >/dev/null 2>&1; then
  helm uninstall gateway -n app >/dev/null 2>&1 || true
  helm uninstall auth -n app >/dev/null 2>&1 || true
  helm uninstall cart -n app >/dev/null 2>&1 || true
  helm uninstall payment -n app >/dev/null 2>&1 || true
fi

if command -v kubectl >/dev/null 2>&1; then
  kubectl delete namespace app --ignore-not-found=true >/dev/null 2>&1 || true
fi

if [ "$MANAGE_ROUTE53" = "true" ] && [ -d "$ROOT_DIR/infrastructure/terraform/route53" ]; then
  tf_init "$ROOT_DIR/infrastructure/terraform/route53"
  pushd "$ROOT_DIR/infrastructure/terraform/route53" >/dev/null
  terraform destroy -auto-approve -var="region=$AWS_REGION" -var="zone_name=$ZONE_NAME"
  popd >/dev/null
fi

if [ -d "$ROOT_DIR/infrastructure/terraform/eks" ] && [ -d "$ROOT_DIR/infrastructure/terraform/vpc" ]; then
  tf_init "$ROOT_DIR/infrastructure/terraform/vpc"
  tf_init "$ROOT_DIR/infrastructure/terraform/eks"
  pushd "$ROOT_DIR/infrastructure/terraform/vpc" >/dev/null
  VPC_ID="$(terraform output -raw vpc_id 2>/dev/null || true)"
  SUBNETS="$(terraform output -json private_subnets 2>/dev/null || true)"
  popd >/dev/null

  if [ -n "$VPC_ID" ] && [ -n "$SUBNETS" ]; then
    pushd "$ROOT_DIR/infrastructure/terraform/eks" >/dev/null
    terraform destroy -auto-approve \
      -var="region=$AWS_REGION" \
      -var="vpc_id=$VPC_ID" \
      -var="subnet_ids=$SUBNETS"
    popd >/dev/null
  fi
fi

if [ -d "$ROOT_DIR/infrastructure/terraform/vpc" ]; then
  tf_init "$ROOT_DIR/infrastructure/terraform/vpc"
  pushd "$ROOT_DIR/infrastructure/terraform/vpc" >/dev/null
  terraform destroy -auto-approve -var="region=$AWS_REGION"
  popd >/dev/null
fi

if [ -d "$ROOT_DIR/infrastructure/terraform/ecr" ]; then
  tf_init "$ROOT_DIR/infrastructure/terraform/ecr"
  pushd "$ROOT_DIR/infrastructure/terraform/ecr" >/dev/null
  terraform destroy -auto-approve -var="region=$AWS_REGION"
  popd >/dev/null
fi

echo "Destroy process completed."
