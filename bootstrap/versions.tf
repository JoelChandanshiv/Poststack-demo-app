terraform {
  # Native S3 state locking (use_lockfile) requires Terraform 1.10+.
  # Pinned to a range rather than an exact version so patch releases are
  # picked up automatically, but a future major version can't silently break this.
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

  # Intentionally NOT configuring a backend block here.
  # This is the bootstrap problem: the S3 backend this project creates
  # cannot be used to store its own state on first run, because it
  # doesn't exist yet. This directory uses the local backend (Terraform's
  # default when no backend block is present).
  #
  # After the first successful `apply`, you can OPTIONALLY migrate this
  # directory's own state into the bucket it just created — see README.md
  # in this directory for the exact steps. That is a one-time, manual
  # `terraform init -migrate-state` command, not a Console action, so it
  # doesn't violate the "no Console changes" requirement.
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}
