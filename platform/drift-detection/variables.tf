variable "aws_region" {
  description = "Region for the drift-check CI control plane - must support AWS CodeConnections (ap-south-2 does not). See main.tf note."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  type    = string
  default = "poststack"
}

variable "github_connection_arn" {
  type = string
}

variable "github_full_repository_id" {
  type = string
}

variable "state_bucket_name" {
  type = string
}

variable "state_bucket_kms_key_arn" {
  type = string
}

variable "dev_branch_name" {
  type    = string
  default = "develop"
}

variable "prod_branch_name" {
  type    = string
  default = "main"
}

variable "dev_schedule" {
  description = "EventBridge schedule expression, UTC."
  type        = string
  default     = "cron(30 2 * * ? *)" # 08:00 IST daily
}

variable "prod_schedule" {
  type    = string
  default = "cron(0 3 * * ? *)" # 08:30 IST daily
}

variable "notification_email" {
  type    = string
  default = ""
}
