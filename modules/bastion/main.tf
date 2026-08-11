locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [var.bastion_sg_id]
  iam_instance_profile   = var.instance_profile_name
  key_name                = var.ssh_key_name

  # Bastion needs a public IP to be reachable by SSH from outside the VPC.
  associate_public_ip_address = true

  metadata_options {
    http_tokens   = "required" # enforce IMDSv2, blocks the older, SSRF-exploitable IMDSv1
    http_endpoint = "enabled"
  }

  root_block_device {
    encrypted   = true
    volume_size = 30 # AL2023 AMI's root snapshot in ap-south-2 requires >= 30GB
    volume_type = "gp3"
  }

  tags = merge(var.tags, { Name = "${local.name_prefix}-bastion" })
}
