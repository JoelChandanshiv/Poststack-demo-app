terraform {
  required_version = ">= 1.10, < 2.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # backend "s3" { ... } goes in backend.tf, created from backend.tf.example,
  # key = "platform/ecr/terraform.tfstate" — separate state from dev/prod
  # since this resource is shared and applied independently of either.
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
  type    = string
  default = "ap-south-2"
}

variable "project_name" {
  type    = string
  default = "poststack"
}

resource "aws_ecr_repository" "app" {
  name = "${var.project_name}-app"

  # IMMUTABLE means a given tag can only ever point at one image — once
  # pushed, that tag can't be silently overwritten. This is what makes
  # "promote this exact image from dev to prod" a meaningful, verifiable
  # statement rather than a race condition.
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

# Keeps the repo from growing unbounded — untagged images (superseded
# builds) get cleaned up automatically instead of needing manual pruning.
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 14 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 14
        }
        action = { type = "expire" }
      }
    ]
  })
}

output "repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "repository_arn" {
  value = aws_ecr_repository.app.arn
}
