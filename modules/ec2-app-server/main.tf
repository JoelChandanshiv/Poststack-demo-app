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

resource "aws_instance" "app" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = var.private_subnet_id
  vpc_security_group_ids = [var.app_sg_id]
  iam_instance_profile   = var.instance_profile_name
  key_name               = var.ssh_key_name

  # No public IP — reachable only via the ALB (inbound) and NAT Gateway
  # (outbound, for ECR/Secrets Manager/package installs).
  associate_public_ip_address = false

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  root_block_device {
    encrypted   = true
    volume_size = var.root_volume_size
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    aws_region = var.aws_region
  })

  # Re-running user_data requires a new instance (Terraform recreates on
  # user_data change by default only if user_data_replace_on_change is
  # set) — left at Terraform's default (update in place, user_data change
  # alone does not force replacement) since app deployment itself goes
  # through CodeDeploy, not through re-running this script.

  tags = merge(var.tags, { Name = "${local.name_prefix}-app-server" })
}

resource "aws_lb_target_group_attachment" "app" {
  target_group_arn = var.target_group_arn
  target_id         = aws_instance.app.id
  port                = var.app_port
}
