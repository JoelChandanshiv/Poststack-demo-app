# Copy this file to backend.tf inside environments/dev and environments/prod,
# filling in <STATE_BUCKET_NAME> and <KMS_KEY_ARN> from bootstrap's outputs
# (`terraform output` inside bootstrap/ after it's applied).
#
# The `key` value below is what differentiates dev from prod within the same
# bucket — this is the actual mechanism that guarantees applying dev never
# touches prod's state. Prod's copy of this file should use key =
# "prod/terraform.tfstate" instead.

terraform {
  backend "s3" {
    bucket       = "poststack-tfstate-764d5977"
    key          = "dev/terraform.tfstate"
    region       = "ap-south-2"
    encrypt      = true
    kms_key_id   = "arn:aws:kms:ap-south-2:345594572087:key/da191789-785b-4b83-91b0-a1bc8b8538c4"

    # Native S3 state locking — Terraform 1.10+. No DynamoDB table required.
    use_lockfile = true
  }
}
