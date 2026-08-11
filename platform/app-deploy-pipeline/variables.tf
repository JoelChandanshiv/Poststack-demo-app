variable "aws_region" {
  description = "Primary region for this pipeline - must match where the app server, ECR repo, and CodeDeploy live. ap-south-2."
  type        = string
  default     = "ap-south-2"
}

variable "connection_region" {
  description = "Region the GitHub CodeConnection lives in - ap-south-1, same limitation as platform/terraform-pipeline."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  type    = string
  default = "poststack"
}

variable "environment" {
  description = "Which environments/<env> app server this deploys to. dev only for now - prod added later as a second instantiation."
  type        = string
  default     = "dev"
}

variable "github_connection_arn" {
  description = "From platform/github-connection's output."
  type        = string
}

variable "github_full_repository_id" {
  type = string
}

variable "branch_name" {
  description = "Branch that triggers this pipeline. Can be the same branch as the Terraform pipeline for this environment, since both watch the same repo but different paths in practice (this one cares about app/** and ci/**, the Terraform one cares about environments/<env>/**) - no path filtering is configured here, so ANY push to this branch triggers an image rebuild+deploy, even infra-only changes. Acceptable for now; revisit if that becomes noisy."
  type        = string
  default     = "develop"
}

variable "ecr_repository_url" {
  description = "From platform/ecr's output."
  type        = string
}

variable "ecr_repository_arn" {
  description = "From platform/ecr's output."
  type        = string
}

variable "app_server_name_tag" {
  description = "Must match the Name tag on the target EC2 instance - CodeDeploy discovers deployment targets by this tag, not by instance ID."
  type        = string
  default     = "poststack-dev-app-server"
}

variable "app_server_role_name" {
  description = "Name of the existing IAM role on the app server (from modules/iam, applied via environments/<env>) - this config attaches an additional policy to it so the CodeDeploy agent can read the deployment artifact from S3."
  type        = string
  default     = "poststack-dev-app-server-role"
}

variable "tags" {
  type    = map(string)
  default = {}
}
