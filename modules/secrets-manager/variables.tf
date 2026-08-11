variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "db_username" {
  description = "Master username for the RDS instance."
  type        = string
  default     = "appadmin"
}

variable "recovery_window_in_days" {
  description = "Days before a deleted secret is permanently removed. 0 = immediate delete (fine for dev), non-zero recommended for prod so an accidental deletion is recoverable."
  type        = number
  default     = 0
}

variable "tags" {
  type    = map(string)
  default = {}
}
