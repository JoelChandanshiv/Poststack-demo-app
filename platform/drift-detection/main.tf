terraform {
  required_version = ">= 1.10, < 2.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
  # backend.tf -> key = "platform/drift-detection/terraform.tfstate"
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Project   = var.project_name
      Scope     = "platform"
    }
  }
}

# NOTE: this whole config (drift-check CodePipelines, CodeBuild, the S3
# report bucket, the Lambda notifier) runs in ap-south-1 by default - same
# reasoning as platform/terraform-pipeline: it uses the same GitHub
# CodeConnection, which ap-south-2 does not support. The `terraform plan`
# that runs inside each drift-check CodeBuild project still targets
# ap-south-2, via each environments/<env> config's own provider region.

data "aws_caller_identity" "current" {}

locals {
  envs = {
    dev = {
      branch   = var.dev_branch_name
      schedule = var.dev_schedule
    }
    prod = {
      branch   = var.prod_branch_name
      schedule = var.prod_schedule
    }
  }
}

# ---------------------------------------------------------------------------
# Shared bucket: CodePipeline artifacts (one prefix) + drift JSON reports
# read by the Lambda (another prefix).
# ---------------------------------------------------------------------------
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "drift" {
  bucket = "${var.project_name}-drift-detection-${random_id.bucket_suffix.hex}"
}

resource "aws_s3_bucket_versioning" "drift" {
  bucket = aws_s3_bucket.drift.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "drift" {
  bucket = aws_s3_bucket.drift.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "drift" {
  bucket                  = aws_s3_bucket.drift.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_sns_topic" "drift_alerts" {
  name = "${var.project_name}-drift-alerts"
}

resource "aws_sns_topic_subscription" "drift_alerts_email" {
  count = var.notification_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.drift_alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email
}
