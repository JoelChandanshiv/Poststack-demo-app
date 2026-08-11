variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "private_subnet_id" {
  type = string
}

variable "app_sg_id" {
  type = string
}

variable "instance_profile_name" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "target_group_arn" {
  description = "ALB target group to register this instance with."
  type        = string
}

variable "app_port" {
  description = "Must match the port the ALB target group and security-groups module use."
  type        = number
  default     = 8080
}

variable "root_volume_size" {
  description = "GB. The AL2023 AMI's root snapshot in ap-south-2 requires at least 30GB - a smaller value will fail at apply time with InvalidBlockDeviceMapping."
  type        = number
  default     = 30
}

variable "ssh_key_name" {
  description = <<-EOT
    Optional. Name of an existing EC2 key pair, for SSH break-glass access
    from the bastion in addition to SSM Session Manager (the recommended
    day-to-day path, since it needs no key file on the bastion and uses
    the same IAM role the app server already has). Leave null to launch
    without any key pair - SSH will simply not be possible, only SSM.
  EOT
  type        = string
  default     = null
}

variable "aws_region" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
