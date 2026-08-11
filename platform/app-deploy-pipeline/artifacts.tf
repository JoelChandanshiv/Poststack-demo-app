locals {
  name_prefix = "${var.project_name}-${var.environment}-app-deploy"
}

resource "random_id" "artifact_suffix" {
  byte_length = 4
}

# ---------------------------------------------------------------------------
# Primary region (ap-south-2) artifact store - used by Build and Deploy actions
# ---------------------------------------------------------------------------
resource "aws_kms_key" "artifacts_primary" {
  description             = "Cross-region CodePipeline artifact encryption - ${local.name_prefix} (ap-south-2)"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(var.tags, { Name = "${local.name_prefix}-artifacts-key-primary" })
}

resource "aws_kms_alias" "artifacts_primary" {
  name          = "alias/${local.name_prefix}-artifacts-primary"
  target_key_id = aws_kms_key.artifacts_primary.key_id
}

resource "aws_s3_bucket" "artifacts_primary" {
  bucket = "${local.name_prefix}-artifacts-primary-${random_id.artifact_suffix.hex}"

  tags = merge(var.tags, { Name = "${local.name_prefix}-artifacts-primary" })
}

resource "aws_s3_bucket_versioning" "artifacts_primary" {
  bucket = aws_s3_bucket.artifacts_primary.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts_primary" {
  bucket = aws_s3_bucket.artifacts_primary.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.artifacts_primary.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts_primary" {
  bucket                  = aws_s3_bucket.artifacts_primary.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------------------------------------------------------------------
# Connection region (ap-south-1) artifact store - used only by the Source
# action, since that's the region the CodeConnection lives in.
# ---------------------------------------------------------------------------
resource "aws_kms_key" "artifacts_connection_region" {
  provider = aws.connection_region

  description             = "Cross-region CodePipeline artifact encryption - ${local.name_prefix} (ap-south-1)"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(var.tags, { Name = "${local.name_prefix}-artifacts-key-connection-region" })
}

resource "aws_kms_alias" "artifacts_connection_region" {
  provider = aws.connection_region

  name          = "alias/${local.name_prefix}-artifacts-connection-region"
  target_key_id = aws_kms_key.artifacts_connection_region.key_id
}

resource "aws_s3_bucket" "artifacts_connection_region" {
  provider = aws.connection_region

  bucket = "${local.name_prefix}-artifacts-conn-${random_id.artifact_suffix.hex}"

  tags = merge(var.tags, { Name = "${local.name_prefix}-artifacts-connection-region" })
}

resource "aws_s3_bucket_versioning" "artifacts_connection_region" {
  provider = aws.connection_region

  bucket = aws_s3_bucket.artifacts_connection_region.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts_connection_region" {
  provider = aws.connection_region

  bucket = aws_s3_bucket.artifacts_connection_region.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.artifacts_connection_region.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts_connection_region" {
  provider = aws.connection_region

  bucket                  = aws_s3_bucket.artifacts_connection_region.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
