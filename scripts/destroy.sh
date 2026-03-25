#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AWS_REGION="${AWS_REGION:-us-west-2}"
ZONE_NAME="${ZONE_NAME:-example.com}"
MANAGE_ROUTE53="${MANAGE_ROUTE53:-false}"

tf_init() {
  bash "$ROOT_DIR/scripts/terraform_init.sh" "$1"
}

wait_for_namespace_deletion() {
  if command -v kubectl >/dev/null 2>&1; then
    kubectl wait --for=delete namespace/app --timeout=10m >/dev/null 2>&1 || true
  fi
}

wait_for_vpc_network_cleanup() {
  local vpc_id="$1"
  local public_subnets="$2"
  local attempts=40

  for ((i=1; i<=attempts; i++)); do
    local elbv2_lbs classic_lbs subnet_a subnet_b eni_ids

    elbv2_lbs="$(aws elbv2 describe-load-balancers \
      --region "$AWS_REGION" \
      --query "LoadBalancers[?VpcId=='$vpc_id'].LoadBalancerArn" \
      --output text 2>/dev/null || true)"

    classic_lbs="$(aws elb describe-load-balancers \
      --region "$AWS_REGION" \
      --query "LoadBalancerDescriptions[?VPCId=='$vpc_id'].LoadBalancerName" \
      --output text 2>/dev/null || true)"

    subnet_a="$(echo "$public_subnets" | tr -d '[]",' | awk '{print $1}')"
    subnet_b="$(echo "$public_subnets" | tr -d '[]",' | awk '{print $2}')"

    eni_ids="$(aws ec2 describe-network-interfaces \
      --region "$AWS_REGION" \
      --filters Name=subnet-id,Values="$subnet_a","$subnet_b" \
      --query "NetworkInterfaces[].NetworkInterfaceId" \
      --output text 2>/dev/null || true)"

    if [ -z "$elbv2_lbs" ] && [ -z "$classic_lbs" ] && [ -z "$eni_ids" ]; then
      echo "AWS network resources have been cleaned up."
      return 0
    fi

    echo "Waiting for AWS load balancer and ENI cleanup ($i/$attempts)..."
    sleep 30
  done

  echo "Timed out waiting for load balancer cleanup; Terraform may still fail on VPC destroy."
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

wait_for_namespace_deletion

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
  PUBLIC_SUBNETS="$(terraform output -json public_subnets 2>/dev/null || true)"
  popd >/dev/null

  if [ -n "$VPC_ID" ] && [ -n "$SUBNETS" ]; then
    pushd "$ROOT_DIR/infrastructure/terraform/eks" >/dev/null
    printf '{\n  "region": "%s",\n  "vpc_id": "%s",\n  "subnet_ids": %s\n}\n' \
      "$AWS_REGION" \
      "$VPC_ID" \
      "$SUBNETS" > runtime.auto.tfvars.json

    terraform destroy -auto-approve -var-file=runtime.auto.tfvars.json
    rm -f runtime.auto.tfvars.json
    popd >/dev/null
  fi
fi

if [ -n "${VPC_ID:-}" ] && [ -n "${PUBLIC_SUBNETS:-}" ]; then
  wait_for_vpc_network_cleanup "$VPC_ID" "$PUBLIC_SUBNETS"
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
