locals {
  common_tags = var.common_tags

  # S3 bucket names are globally unique across all of AWS, not just your
  # account. A random suffix avoids a name collision blocking apply.
  state_bucket_name = "${var.project_name}-tfstate-${random_id.state_bucket_suffix.hex}"
}

resource "random_id" "state_bucket_suffix" {
  byte_length = 4
}

# ---------------------------------------------------------------------------
# KMS key dedicated to encrypting Terraform state objects.
# A dedicated key (rather than the AWS-managed aws/s3 key) lets you control
# the key policy precisely — i.e. only the specific IAM principals that run
# Terraform (your dev server role today, the CI/CD pipeline roles later)
# can decrypt state, which is where sensitive values (e.g. DB passwords
# written into state) actually live.
# ---------------------------------------------------------------------------
resource "aws_kms_key" "state_bucket_key" {
  description             = "KMS key for encrypting the ${var.project_name} Terraform state bucket"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-tfstate-key"
  })
}

resource "aws_kms_alias" "state_bucket_key" {
  name          = "alias/${var.project_name}-tfstate"
  target_key_id = aws_kms_key.state_bucket_key.key_id
}

# ---------------------------------------------------------------------------
# The Terraform state bucket itself.
#
# object_lock_enabled is a creation-time-only argument — it cannot be added
# to an existing bucket. This is exactly the kind of AWS lifecycle
# constraint the project requirements call out: the decision has to be made
# correctly on the very first apply.
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "state" {
  bucket = local.state_bucket_name

  object_lock_enabled = true

  tags = merge(local.common_tags, {
    Name = local.state_bucket_name
  })
}

# Object Lock requires versioning to be enabled — every write creates a new
# version rather than overwriting, which is also exactly what you want for
# a state file's history and recoverability.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_object_lock_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = var.object_lock_retention_days
    }
  }

  depends_on = [aws_s3_bucket_versioning.state]
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.state_bucket_key.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Deny any request that isn't over TLS, and deny any upload that doesn't
# use the bucket's designated KMS key — belt-and-suspenders on top of the
# default encryption configuration above.
data "aws_iam_policy_document" "state_bucket_policy" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["s3:*"]
    resources = [
      aws_s3_bucket.state.arn,
      "${aws_s3_bucket.state.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid    = "DenyIncorrectEncryptionHeader"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.state.arn}/*"]

    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["aws:kms"]
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.state_bucket_policy.json

  depends_on = [aws_s3_bucket_public_access_block.state]
}

# ---------------------------------------------------------------------------
# NOTE on state locking:
# There is no DynamoDB table here on purpose. Terraform >= 1.10 supports
# native S3-based locking via `use_lockfile = true` in the backend "s3"
# block of each *consumer* configuration (environments/dev, environments/prod,
# platform/*). That setting lives in each of those directories' backend.tf,
# not here — bootstrap itself doesn't need locking since it's a one-time,
# single-operator run. See environments/dev/backend.tf.example below.
# ---------------------------------------------------------------------------
