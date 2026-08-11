variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  description = "Needed to construct region-scoped ARNs for the bastion's SSM caller policy."
  type        = string
}

variable "ecr_repository_arns" {
  description = "ECR repository ARNs the app server is allowed to pull images from."
  type        = list(string)
}

variable "secret_arns" {
  description = "Secrets Manager secret ARNs the app server is allowed to read."
  type        = list(string)
}

variable "kms_key_arns" {
  description = "KMS key ARNs needed to decrypt the above secrets, if they use a customer-managed key."
  type        = list(string)
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
