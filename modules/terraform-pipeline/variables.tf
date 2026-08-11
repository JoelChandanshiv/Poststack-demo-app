variable "project_name" {
  type = string
}

variable "environment" {
  description = "dev or prod - this is which environments/<env> directory this pipeline instance targets."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be \"dev\" or \"prod\"."
  }
}

variable "aws_region" {
  description = "Region the CodeBuild/CodePipeline control-plane resources are created in - must be a region that supports AWS CodeConnections. Not necessarily the same region the Terraform inside CodeBuild deploys infrastructure into (each environments/<env> config sets its own provider region independently)."
  type        = string
  default     = "ap-south-1"
}

variable "github_connection_arn" {
  description = "From platform/github-connection's output."
  type        = string
}

variable "github_full_repository_id" {
  description = "owner/repo, e.g. \"my-org/poststack-infra\"."
  type        = string
}

variable "branch_name" {
  description = "Branch that triggers this pipeline. Recommend a dedicated branch per environment (e.g. \"develop\" for dev, \"main\" for prod) so a push can only ever trigger the pipeline for the environment it's meant for."
  type        = string
}

variable "require_manual_approval" {
  description = "true for prod. When true, a human must approve the plan before apply runs."
  type        = bool
  default     = true
}

variable "state_bucket_name" {
  description = "From bootstrap's output."
  type        = string
}

variable "state_bucket_kms_key_arn" {
  description = "From bootstrap's output."
  type        = string
}

variable "notification_email" {
  description = "Email notified on manual-approval requests. Leave empty to skip."
  type        = string
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
