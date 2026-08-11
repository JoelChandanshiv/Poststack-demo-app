variable "aws_region" {
  description = "AWS region for the Terraform state backend."
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

variable "object_lock_retention_days" {
  description = <<-EOT
    Default S3 Object Lock retention period, in days, applied to state
    objects in Governance mode. Governance mode (not Compliance mode) is
    used deliberately: it protects the state file against accidental or
    malicious deletion while still allowing Terraform (running as an
    authorized principal) to overwrite the object on every apply.
    Compliance mode would block Terraform's own writes.
  EOT
  type        = number
  default     = 7
}

variable "common_tags" {
  description = "Tags applied to every resource this project creates, merged with resource-specific tags."
  type        = map(string)
  default = {
    ManagedBy = "terraform"
    Project   = "poststack"
    Scope     = "bootstrap"
  }
}
