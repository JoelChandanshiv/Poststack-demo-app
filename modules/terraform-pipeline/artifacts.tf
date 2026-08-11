locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

resource "random_id" "artifact_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "artifacts" {
  bucket = "${local.name_prefix}-pipeline-artifacts-${random_id.artifact_suffix.hex}"

  tags = merge(var.tags, { Name = "${local.name_prefix}-pipeline-artifacts" })
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Pipeline artifacts (plan output, source snapshots) don't need to be kept
# forever - old build artifacts pile up otherwise.
resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    id     = "expire-old-artifacts"
    status = "Enabled"

    filter {}

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

resource "aws_sns_topic" "approvals" {
  count = var.require_manual_approval ? 1 : 0

  name = "${local.name_prefix}-tf-approvals"

  tags = merge(var.tags, { Name = "${local.name_prefix}-tf-approvals" })
}

resource "aws_sns_topic_subscription" "approvals_email" {
  count = var.require_manual_approval && var.notification_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.approvals[0].arn
  protocol  = "email"
  endpoint  = var.notification_email
}
