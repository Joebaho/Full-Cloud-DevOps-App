# Full Cloud DevOps App

This repository is a small three-service demo deployed on AWS with Terraform, EKS, Helm, GitHub Actions, and a remote Terraform backend stored in S3 with DynamoDB locking.

## What is in the repo

- `services/auth`: Flask service that calls the cart service.
- `services/cart`: Go service that checks the payment service.
- `services/payment`: Flask payment service.
- `helm/*`: Helm charts for each service and the external gateway.
- `infrastructure/terraform/vpc`: VPC and subnets.
- `infrastructure/terraform/eks`: EKS cluster and managed node group.
- `infrastructure/terraform/ecr`: ECR repositories for the service images.
- `infrastructure/terraform/route53`: Optional hosted zone creation.
- `.github/workflows`: Build, deploy, and destroy GitHub Actions workflows.

## Prerequisites

- AWS account with permissions for ECR, EKS, VPC, S3, DynamoDB, IAM, and Route53.
- `terraform >= 1.6`
- `aws` CLI
- `kubectl`
- `helm`
- `docker`

## 1. Configure the existing remote Terraform state

This project is already configured to use your existing backend in `us-west-2`:

```bash
baho-backup-bucket/full-devops-state
```

with DynamoDB locking in:

```bash
full-devops-table
```

Export these values for local runs:

```bash
export AWS_REGION=us-west-2
export TF_STATE_BUCKET="baho-backup-bucket"
export TF_LOCK_TABLE="full-devops-table"
export TF_STATE_REGION="$AWS_REGION"
export TF_STATE_KEY_PREFIX="full-devops-state"
export AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
export MANAGE_ROUTE53=false
```

## 2. Build and push images

```bash
export IMAGE_TAG=latest
bash scripts/build.sh
```

This pushes `auth-service`, `cart-service`, and `payment-service` to ECR.

## 3. Deploy the stack

Choose a Route53 zone name before deploying:

```bash
export ZONE_NAME=example.com
bash scripts/deploy.sh
```

The deploy script will:

- initialize Terraform with the remote backend when the backend variables are set
- store Terraform state under `baho-backup-bucket/full-devops-state/...`
- create ECR repositories
- create the VPC
- create the EKS cluster
- update local kubeconfig
- optionally create the Route53 hosted zone when `MANAGE_ROUTE53=true`
- install the four Helm releases into the `app` namespace

After deployment:

```bash
kubectl get svc -n app
```

Use the external address from the `gateway` service to reach:

- `/auth/`
- `/cart/`
- `/payment/`

## 4. Destroy everything

```bash
export ZONE_NAME=example.com
bash scripts/destroy.sh
```

This removes the Helm releases first, then tears down Route53 when enabled, EKS, VPC, and ECR.

## GitHub Actions secrets

Set these repository secrets:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_ACCOUNT_ID`
- `AWS_REGION`
- `ROUTE53_ZONE_NAME`
- `MANAGE_ROUTE53`

Optional secrets if you want to override the built-in backend defaults:

- `TF_STATE_BUCKET`
- `TF_LOCK_TABLE`
- `TF_STATE_REGION`
- `TF_STATE_KEY_PREFIX`

Available workflows:

- `Build And Push`: builds and pushes all service images.
- `Deploy Stack`: deploys the infrastructure and Helm releases. It runs automatically after a successful image build on `main`, or manually.
- `Destroy Infrastructure`: manual workflow that requires typing `destroy`.

## Notes

- The working GitHub Actions directory is `.github/workflows`. The older `github/workflows` path was incorrect and has been removed.
- Pushes to `main` trigger image build first, then deployment automatically through GitHub Actions.
- The gateway now uses a `LoadBalancer` service, so the default deployment path does not require the AWS Load Balancer Controller.
- Route53 is disabled by default. Set `MANAGE_ROUTE53=true` only if you want Terraform to create and later destroy a hosted zone.
- Replace placeholder values such as `example.com` and `REPLACE_ME` before using Route53 or ArgoCD in a real AWS account.

## 👨‍💻 Author

**Joseph Mbatchou**

• DevOps / Cloud / Platform  Engineer   
• Content Creator / AWS Builder

## 🔗 Connect With Me

🌐 Website: [https://platform.joebahocloud.com](https://platform.joebahocloud.com)

💼 LinkedIn: [https://www.linkedin.com/in/josephmbatchou/](https://www.linkedin.com/in/josephmbatchou/)

🐦 X/Twitter: [https://www.twitter.com/Joebaho237](https://www.twitter.com/Joebaho237)

▶️ YouTube: [https://www.youtube.com/@josephmbatchou5596](https://www.youtube.com/@josephmbatchou5596)

🔗 Github: [https://github.com/Joebaho](https://github.com/Joebaho)

📦 Dockerhub: [https://hub.docker.com/u/joebaho2](https://hub.docker.com/u/joebaho2)

---

## 📄 License

This project is licensed under the MIT License — see the LICENSE file for details.
