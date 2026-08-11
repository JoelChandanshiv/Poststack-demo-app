variable "aws_region" {
  description = "AWS region for dev resources."
  type        = string
  default     = "ap-south-2"

  validation {
    condition     = var.aws_region == "ap-south-2"
    error_message = "This project is scoped to ap-south-2 (Hyderabad) unless explicitly changed by the team."
  }
}

variable "project_name" {
  description = "Short project identifier, used in resource names and tags."
  type        = string
  default     = "poststack"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the dev VPC."
  type        = string
  default     = "10.10.0.0/16"
}

variable "availability_zones" {
  description = "AZs used for dev subnets. ap-south-2 currently has 3 AZs (ap-south-2a/b/c) — 2 is sufficient for dev."
  type        = list(string)
  default     = ["ap-south-2a", "ap-south-2b"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs, one per AZ."
  type        = list(string)
  default     = ["10.10.0.0/24", "10.10.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs, one per AZ."
  type        = list(string)
  default     = ["10.10.10.0/24", "10.10.11.0/24"]
}

variable "app_port" {
  description = "Port the application container listens on."
  type        = number
  default     = 8080
}

variable "health_check_path" {
  type    = string
  default = "/health"
}

variable "admin_cidr_blocks" {
  description = "CIDR blocks allowed to SSH into the bastion. Set this to your actual admin/office IP range(s) in terraform.tfvars — never leave it as 0.0.0.0/0."
  type        = list(string)
}

variable "bastion_ssh_key_name" {
  description = "Name of an EC2 key pair created via `aws ec2 create-key-pair` beforehand. See modules/bastion/variables.tf for the exact command."
  type        = string
}

variable "db_name" {
  type    = string
  default = "appdb"
}

variable "db_username" {
  type    = string
  default = "appadmin"
}

variable "ecr_repository_arn" {
  description = "ARN of the shared ECR repo, from platform/ecr's outputs (applied separately, once, not per-environment)."
  type        = string
}

variable "alarm_email" {
  description = "Email to receive CloudWatch alarm notifications. Leave empty to skip the subscription."
  type        = string
  default     = ""
}
