variable "aws_region" {
  description = "AWS region for prod resources."
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
  default     = "prod"
}

variable "vpc_cidr" {
  description = "CIDR block for the prod VPC. Deliberately a different range from dev (10.10.0.0/16) so the two could be VPC-peered later without an overlap conflict, even though nothing currently requires peering."
  type        = string
  default     = "10.20.0.0/16"
}

variable "availability_zones" {
  description = "AZs used for prod subnets — 2 minimum, matches dev for consistency."
  type        = list(string)
  default     = ["ap-south-2a", "ap-south-2b"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs, one per AZ."
  type        = list(string)
  default     = ["10.20.0.0/24", "10.20.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs, one per AZ."
  type        = list(string)
  default     = ["10.20.10.0/24", "10.20.11.0/24"]
}

variable "app_port" {
  type    = number
  default = 8080
}

variable "health_check_path" {
  type    = string
  default = "/health"
}

variable "admin_cidr_blocks" {
  description = "CIDR blocks allowed to SSH into the bastion. Set to your real admin range(s) — never 0.0.0.0/0."
  type        = list(string)
}

variable "bastion_ssh_key_name" {
  description = "Name of an EC2 key pair created via `aws ec2 create-key-pair` beforehand. Use a DIFFERENT key pair from dev."
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

variable "db_instance_class" {
  description = "Larger than dev's db.t3.micro — size based on actual prod load once you have a baseline."
  type        = string
  default     = "db.t3.medium"
}

variable "db_allocated_storage" {
  type    = number
  default = 50
}

variable "app_instance_type" {
  description = "Larger than dev's t3.micro — size based on actual prod load."
  type        = string
  default     = "t3.small"
}

variable "ecr_repository_arn" {
  description = "Same ECR repo ARN as dev — images are built once and promoted from dev to prod, not rebuilt per environment."
  type        = string
}

variable "alarm_email" {
  description = "Strongly recommended to set for prod — this is where CPU/storage alarms actually go."
  type        = string
  default     = ""
}
