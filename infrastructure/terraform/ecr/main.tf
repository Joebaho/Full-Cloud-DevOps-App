terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = var.region
}

variable "region" {
  type    = string
  default = "us-west-2"
}

resource "aws_ecr_repository" "auth" {
  name                 = "auth-service"
  image_tag_mutability = "MUTABLE"
}

resource "aws_ecr_repository" "cart" {
  name                 = "cart-service"
  image_tag_mutability = "MUTABLE"
}

resource "aws_ecr_repository" "payment" {
  name                 = "payment-service"
  image_tag_mutability = "MUTABLE"
}
