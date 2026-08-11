variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "private_subnet_ids" {
  description = "At least 2 private subnet IDs, in different AZs — required for the DB subnet group even when multi_az is false."
  type        = list(string)
}

variable "db_security_group_id" {
  type = string
}

variable "db_name" {
  type    = string
  default = "appdb"
}

variable "db_username" {
  type      = string
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "engine_version" {
  description = "PostgreSQL major.minor version."
  type        = string
  default     = "16"
}

variable "instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Storage in GB."
  type        = number
  default     = 20
}

variable "multi_az" {
  description = "true for prod, false for dev."
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Days of automated backups to retain."
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "true for prod. When true, RDS refuses terraform destroy until this is turned off first — intentional friction for prod."
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "true for dev (fast teardown), false for prod (always keep a final snapshot on destroy)."
  type        = bool
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
