variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "app_instance_id" {
  type = string
}

variable "db_instance_id" {
  type = string
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "alarm_email" {
  description = "Email address subscribed to the alerts SNS topic. Leave empty to skip the subscription (topic still gets created)."
  type        = string
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
