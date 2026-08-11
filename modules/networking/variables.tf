variable "project_name" {
  description = "Short project identifier, used in resource names."
  type        = string
}

variable "environment" {
  description = "Environment name (dev or prod). Used in resource names and tags."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be either \"dev\" or \"prod\"."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "availability_zones" {
  description = <<-EOT
    List of AZs to spread subnets across. Minimum 2 required — the ALB
    (Phase 3, later module) requires subnets in at least 2 AZs, and RDS
    Multi-AZ (prod) requires a subnet group spanning at least 2 AZs even
    if you're not using Multi-AZ in dev.
  EOT
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least 2 availability zones are required."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets, one per AZ, same order as availability_zones."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets, one per AZ, same order as availability_zones."
  type        = list(string)
}

variable "single_nat_gateway" {
  description = <<-EOT
    If true, creates exactly one NAT Gateway (in the first public subnet)
    shared by all private subnets — cheaper, no cross-AZ NAT redundancy.
    If false, creates one NAT Gateway per AZ for full HA.
    Use true for dev, false for prod.
  EOT
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags merged into every resource this module creates."
  type        = map(string)
  default     = {}
}
