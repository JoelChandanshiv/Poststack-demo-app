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
  # backend.tf -> key = "platform/app-deploy-pipeline/terraform.tfstate"
}

# ---------------------------------------------------------------------------
# This config genuinely needs two regions, unlike platform/terraform-pipeline:
#   - ap-south-2: CodeBuild (pushes to ECR), CodeDeploy (deploys to the EC2
#     app server) - both MUST be in the same region as the app server and
#     ECR repo, since CodeDeploy deployment groups discover EC2 instances
#     within their own region only, and cannot target instances elsewhere.
#   - ap-south-1: the GitHub CodeStarConnection Source action - same
#     CodeConnections regional limitation as platform/terraform-pipeline.
# This means the pipeline needs CodePipeline's cross-region actions
# feature: an artifact store (S3 bucket + KMS key, since cross-region
# actions require a customer-managed key, not the default AWS-managed one)
# in EACH region, and the Source action explicitly pinned to ap-south-1
# while Build/Deploy default to the pipeline's own primary region.
# ---------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region # ap-south-2 - primary region for this pipeline

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Project   = var.project_name
      Scope     = "platform"
    }
  }
}

provider "aws" {
  alias  = "connection_region"
  region = var.connection_region # ap-south-1

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Project   = var.project_name
      Scope     = "platform"
    }
  }
}

data "aws_caller_identity" "current" {}
