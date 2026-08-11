terraform {
  required_version = ">= 1.10, < 2.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
  # backend.tf -> key = "platform/terraform-pipeline/terraform.tfstate"
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

variable "aws_region" {
  description = <<-EOT
    Region for the CI/CD control plane itself (CodePipeline, CodeBuild,
    the artifact bucket, the GitHub connection) - NOT the region
    infrastructure gets deployed into. Defaults to ap-south-1 because
    AWS CodeConnections does not support ap-south-2 (see
    platform/github-connection/main.tf for the full explanation). The
    Terraform inside the CodeBuild "apply" step still targets ap-south-2,
    since environments/dev and environments/prod each configure their own
    AWS provider region independently - that's a separate, unaffected
    setting from where CodeBuild itself executes.
  EOT
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  type    = string
  default = "poststack"
}

variable "github_connection_arn" {
  description = "From platform/github-connection's output. Connection must show AVAILABLE status (i.e. the one-time manual authorization is done) before this pipeline can pull source successfully."
  type        = string
}

variable "github_full_repository_id" {
  type = string
}

variable "state_bucket_name" {
  description = "From bootstrap's output."
  type        = string
}

variable "state_bucket_kms_key_arn" {
  description = "From bootstrap's output."
  type        = string
}

variable "dev_branch_name" {
  type    = string
  default = "develop"
}

variable "prod_branch_name" {
  type    = string
  default = "main"
}

variable "notification_email" {
  description = "Email notified when a prod apply needs manual approval."
  type        = string
  default     = ""
}

module "dev_pipeline" {
  source = "../../modules/terraform-pipeline"

  project_name = var.project_name
  environment  = "dev"
  aws_region   = var.aws_region

  github_connection_arn     = var.github_connection_arn
  github_full_repository_id = var.github_full_repository_id
  branch_name                = var.dev_branch_name

  # Dev applies without a human in the loop - the whole point of having a
  # dev environment is fast iteration. Prod is where approval matters.
  require_manual_approval = false

  state_bucket_name        = var.state_bucket_name
  state_bucket_kms_key_arn = var.state_bucket_kms_key_arn

  tags = {
    ManagedBy = "terraform"
    Project   = var.project_name
  }
}

module "prod_pipeline" {
  source = "../../modules/terraform-pipeline"

  project_name = var.project_name
  environment  = "prod"
  aws_region   = var.aws_region

  github_connection_arn     = var.github_connection_arn
  github_full_repository_id = var.github_full_repository_id
  branch_name                = var.prod_branch_name

  require_manual_approval = true
  notification_email       = var.notification_email

  state_bucket_name        = var.state_bucket_name
  state_bucket_kms_key_arn = var.state_bucket_kms_key_arn

  tags = {
    ManagedBy = "terraform"
    Project   = var.project_name
  }
}

output "dev_pipeline_name" {
  value = module.dev_pipeline.pipeline_name
}

output "prod_pipeline_name" {
  value = module.prod_pipeline.pipeline_name
}
