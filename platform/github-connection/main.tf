terraform {
  required_version = ">= 1.10, < 2.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # backend.tf -> key = "platform/github-connection/terraform.tfstate"
  # (the STATE for this config still lives in the ap-south-2 state bucket
  # from bootstrap - only the connection resource itself is created in a
  # different region, see aws_region below)
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
    AWS CodeConnections (the service behind aws_codestarconnections_connection)
    does not support ap-south-2 (Hyderabad) - confirmed against AWS's own
    region-availability docs after hitting a DNS resolution failure trying
    to create this resource there. ap-south-1 (Mumbai) is the nearest
    region that does support it, so that's where this one resource - and
    only this resource plus the CodePipeline/CodeBuild control plane in
    modules/terraform-pipeline and platform/drift-detection that depend on
    it - is created. The actual infrastructure (environments/dev,
    environments/prod) stays entirely in ap-south-2, unaffected - a
    Terraform AWS provider's region is independent of which region the
    CodeBuild job invoking it happens to run in.
  EOT
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  type    = string
  default = "poststack"
}

# This resource is fully Terraform-managed. What is NOT Terraform-managed
# is the OAuth handshake that authorizes it to actually talk to your GitHub
# account/org - that is a one-time interactive step AWS requires be done
# in the Console (Developer Tools -> Settings -> Connections -> Update
# pending connection), because it's literally you granting AWS an OAuth
# token, which cannot be scripted without you being present at GitHub's
# login page. This is the one legitimate exception to "no Console usage"
# in this whole project: it's not a way of creating/modifying infrastructure,
# it's an identity handshake AWS's own architecture requires a human for.
resource "aws_codestarconnections_connection" "github" {
  name          = "${var.project_name}-github"
  provider_type = "GitHub"
}

output "connection_arn" {
  description = "Pass this into modules/terraform-pipeline. Status will be PENDING until you complete the one-time authorization in the Console."
  value       = aws_codestarconnections_connection.github.arn
}

output "connection_status" {
  value = aws_codestarconnections_connection.github.connection_status
}
