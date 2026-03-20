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

variable "zone_name" {
  type        = string
  description = "Route53 hosted zone name"
}

resource "aws_route53_zone" "main" {
  name = var.zone_name
}

output "zone_id" {
  value = aws_route53_zone.main.zone_id
}
