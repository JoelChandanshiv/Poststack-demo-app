variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  description = "At least 2 subnets in different AZs — ALB requires this."
  type        = list(string)
}

variable "alb_sg_id" {
  type = string
}

variable "app_port" {
  type    = number
  default = 8080
}

variable "health_check_path" {
  type    = string
  default = "/health"
}

variable "deletion_protection" {
  description = "true for prod."
  type        = bool
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
