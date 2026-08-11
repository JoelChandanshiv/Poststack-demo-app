variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "public_subnet_id" {
  type = string
}

variable "bastion_sg_id" {
  type = string
}

variable "instance_profile_name" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "ssh_key_name" {
  description = <<-EOT
    Name of an EC2 key pair that already exists in this account/region.
    Create it via CLI, not the Console, e.g.:
      aws ec2 create-key-pair --key-name poststack-dev-bastion \
        --query 'KeyMaterial' --output text > poststack-dev-bastion.pem
      chmod 400 poststack-dev-bastion.pem
    Terraform intentionally does not generate this key pair itself —
    doing so would put the private key material in Terraform state,
    which is a real security exposure for something meant to stay secret.
  EOT
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
