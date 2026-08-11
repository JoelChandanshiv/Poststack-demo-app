variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "db_instance_arn" {
  type = string
}

variable "schedule" {
  description = "Cron expression, UTC. Default: daily at 20:00 UTC = 01:30 IST."
  type        = string
  default     = "cron(0 20 * * ? *)"
}

variable "retention_days" {
  type    = number
  default = 14
}

variable "tags" {
  type    = map(string)
  default = {}
}
