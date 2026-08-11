terraform {
  required_version = ">= 1.10, < 2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # backend "s3" { ... } lives in backend.tf, which you create from
  # backend.tf.example using bootstrap's outputs. Not inlined here so
  # this file has no environment-specific values in it.
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}
