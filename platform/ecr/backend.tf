# Copy to backend.tf, fill in from bootstrap's outputs. This is shared/
# platform state, separate from both dev and prod.

terraform {
  backend "s3" {
    bucket       = "poststack-tfstate-764d5977"
    key          = "platform/ecr/terraform.tfstate"
    region       = "ap-south-2"
    encrypt      = true
    kms_key_id   = "arn:aws:kms:ap-south-2:345594572087:key/da191789-785b-4b83-91b0-a1bc8b8538c4"
    use_lockfile = true
  }
}
