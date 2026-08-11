# Bootstrap — Terraform Remote State Backend

Creates the S3 bucket (+ KMS key) that every other Terraform configuration
in this project (`environments/dev`, `environments/prod`, `platform/*`)
uses as its remote state backend. Run this exactly once, from your dev
server, using a local state file — that's the standard, correct way to
solve the "backend can't depend on itself" bootstrap problem.

## Prerequisites

- Terraform >= 1.10 (`terraform version`)
- AWS CLI v2, configured with credentials that can create S3/KMS resources
  (`aws sts get-caller-identity` should succeed)
- Confirm your account has no service-level restriction on `ap-south-2`
  (Hyderabad) — it's a newer region, verify before relying on it further.

## Steps

```bash
cd bootstrap

# 1. Format and validate before anything else
terraform fmt -check
terraform init
terraform validate

# 2. (Optional but recommended) lint before apply
tflint --init
tflint

# 3. Review the plan carefully — this is the only apply in the project
#    that isn't running through the CI/CD pipeline yet
terraform plan -out=bootstrap.tfplan

# 4. Apply
terraform apply bootstrap.tfplan

# 5. Capture the outputs — you'll need these for every other directory's backend.tf
terraform output
```

## After apply: migrating bootstrap's own state (optional, recommended)

Right now this directory's state lives locally on your dev server, which
is a single point of failure and isn't shared with anyone else on the
team. Migrate it into the bucket it just created:

1. Create `bootstrap/backend.tf` using the values from `terraform output`:

   ```hcl
   terraform {
     backend "s3" {
       bucket       = "<state_bucket_name output>"
       key          = "bootstrap/terraform.tfstate"
       region       = "ap-south-2"
       encrypt      = true
       kms_key_id   = "<state_bucket_kms_key_arn output>"
       use_lockfile = true
     }
   }
   ```

2. Run `terraform init -migrate-state` and confirm when prompted. Terraform
   copies the local state into the bucket and the local `terraform.tfstate`
   file becomes redundant (keep it briefly as a safety copy, then remove
   it from disk — never commit it to git).

## Wiring up environments/dev and environments/prod

1. `cp environments/dev/backend.tf.example environments/dev/backend.tf`
   and `cp environments/prod/backend.tf.example environments/prod/backend.tf`
2. Replace `<STATE_BUCKET_NAME>` and `<KMS_KEY_ARN>` in both files with the
   values from `terraform output` in this directory.
3. Those two directories are otherwise empty right now (Phase 3–4 of the
   project plan) — this just makes sure the backend is ready before any
   resources are defined there.

## What this created

- One S3 bucket, versioned, KMS-encrypted (dedicated key, not the AWS-managed
  default), all four Block Public Access settings on, bucket-owner-enforced
  ownership, Object Lock enabled in Governance mode, plus a bucket policy
  denying non-TLS requests and uploads that don't use the designated KMS key.
- One KMS key with rotation enabled, dedicated to this bucket.
- No DynamoDB table — state locking for consumers of this bucket uses
  Terraform's native S3 locking (`use_lockfile = true`), available in
  Terraform 1.10+.

## Why no CI/CD for this directory

Bootstrap is the one piece of this project that's expected to run manually,
once, by a human — because the CI/CD pipeline itself (Phase 5 of the
project plan) needs somewhere to store *its own* Terraform state, which
means this bucket has to exist first. Every other directory in this repo
is designed to run exclusively through the pipeline going forward.
