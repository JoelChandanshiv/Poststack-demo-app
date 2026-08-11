output "state_bucket_name" {
  description = "Name of the S3 bucket storing Terraform state. Use this in environments/*/backend.tf and platform/*/backend.tf."
  value       = aws_s3_bucket.state.id
}

output "state_bucket_arn" {
  description = "ARN of the Terraform state bucket."
  value       = aws_s3_bucket.state.arn
}

output "state_bucket_kms_key_arn" {
  description = "ARN of the KMS key used to encrypt state objects. IAM policies for CI/CD roles must grant kms:Decrypt/kms:GenerateDataKey on this key."
  value       = aws_kms_key.state_bucket_key.arn
}

output "aws_region" {
  description = "Region the backend was created in — must match the region used in every backend.tf that references this bucket."
  value       = var.aws_region
}
