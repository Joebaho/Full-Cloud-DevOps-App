#!/bin/bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "usage: $0 <terraform-directory>"
  exit 1
fi

TF_DIR="$1"
AWS_REGION="${AWS_REGION:-us-west-2}"

pushd "$TF_DIR" >/dev/null

if [ -n "${TF_STATE_BUCKET:-}" ] && [ -n "${TF_LOCK_TABLE:-}" ]; then
  KEY_PREFIX="${TF_STATE_KEY_PREFIX:-full-devops-state}"
  TF_ROOT="$(git rev-parse --show-toplevel)/infrastructure/terraform"
  KEY_PATH="${TF_DIR#$TF_ROOT/}/terraform.tfstate"

  terraform init -input=false \
    -backend-config="bucket=$TF_STATE_BUCKET" \
    -backend-config="key=$KEY_PREFIX/$KEY_PATH" \
    -backend-config="region=${TF_STATE_REGION:-$AWS_REGION}" \
    -backend-config="dynamodb_table=$TF_LOCK_TABLE" \
    -backend-config="encrypt=true"
else
  terraform init -input=false
fi

popd >/dev/null
