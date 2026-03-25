#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AWS_REGION="${AWS_REGION:-us-west-2}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
ZONE_NAME="${ZONE_NAME:-example.com}"
MANAGE_ROUTE53="${MANAGE_ROUTE53:-false}"
ACCOUNT_ID="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}"
REGISTRY="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

tf_init() {
  bash "$ROOT_DIR/scripts/terraform_init.sh" "$1"
}

bash "$ROOT_DIR/scripts/apply_ecr.sh"

tf_init "$ROOT_DIR/infrastructure/terraform/vpc"
pushd "$ROOT_DIR/infrastructure/terraform/vpc" >/dev/null
terraform apply -auto-approve -var="region=$AWS_REGION"
VPC_ID="$(terraform output -raw vpc_id)"
SUBNETS="$(terraform output -json private_subnets)"
popd >/dev/null

tf_init "$ROOT_DIR/infrastructure/terraform/eks"
pushd "$ROOT_DIR/infrastructure/terraform/eks" >/dev/null
printf '{\n  "region": "%s",\n  "vpc_id": "%s",\n  "subnet_ids": %s\n}\n' \
  "$AWS_REGION" \
  "$VPC_ID" \
  "$SUBNETS" > runtime.auto.tfvars.json

terraform apply -auto-approve -var-file=runtime.auto.tfvars.json
CLUSTER_NAME="$(terraform output -raw cluster_name)"
rm -f runtime.auto.tfvars.json
popd >/dev/null

aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

if [ "$MANAGE_ROUTE53" = "true" ]; then
  tf_init "$ROOT_DIR/infrastructure/terraform/route53"
  pushd "$ROOT_DIR/infrastructure/terraform/route53" >/dev/null
  terraform apply -auto-approve -var="region=$AWS_REGION" -var="zone_name=$ZONE_NAME"
  popd >/dev/null
fi

helm upgrade --install payment "$ROOT_DIR/helm/payment-service" \
  --namespace app --create-namespace \
  --set image.repository="$REGISTRY/payment-service" \
  --set image.tag="$IMAGE_TAG"

helm upgrade --install cart "$ROOT_DIR/helm/cart-service" \
  --namespace app --create-namespace \
  --set image.repository="$REGISTRY/cart-service" \
  --set image.tag="$IMAGE_TAG"

helm upgrade --install auth "$ROOT_DIR/helm/auth-service" \
  --namespace app --create-namespace \
  --set image.repository="$REGISTRY/auth-service" \
  --set image.tag="$IMAGE_TAG"

helm upgrade --install gateway "$ROOT_DIR/helm/gateway" \
  --namespace app --create-namespace

kubectl rollout status deployment/payment -n app --timeout=180s
kubectl rollout status deployment/cart -n app --timeout=180s
kubectl rollout status deployment/auth -n app --timeout=180s
kubectl rollout status deployment/gateway -n app --timeout=180s

echo "Deployment completed."
