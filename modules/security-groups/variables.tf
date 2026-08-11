variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "app_port" {
  description = "Port the application listens on inside the app server container."
  type        = number
  default     = 8080
}

variable "admin_cidr_blocks" {
  description = "CIDR blocks allowed to SSH into the bastion host. Never default this to 0.0.0.0/0 — pass your actual admin IP range(s)."
  type        = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}
