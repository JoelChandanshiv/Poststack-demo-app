locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ---------------------------------------------------------------------------
# ALB: only SG in this module that accepts traffic from the internet.
# ---------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "ALB - allows inbound HTTP/HTTPS from the internet"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${local.name_prefix}-alb-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4          = "0.0.0.0/0"
  from_port           = 80
  to_port              = 80
  ip_protocol          = "tcp"
  description          = "HTTP from internet"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4          = "0.0.0.0/0"
  from_port           = 443
  to_port              = 443
  ip_protocol          = "tcp"
  description          = "HTTPS from internet (requires an ACM cert + listener added once a domain exists)"
}

resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4          = "0.0.0.0/0"
  ip_protocol         = "-1"
  description         = "All outbound (to app servers in private subnets)"
}

# ---------------------------------------------------------------------------
# Bastion: only SG that accepts SSH, and only from admin CIDRs — never from
# the ALB SG or 0.0.0.0/0.
# ---------------------------------------------------------------------------
resource "aws_security_group" "bastion" {
  name        = "${local.name_prefix}-bastion-sg"
  description = "Bastion host - SSH from admin CIDRs only"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${local.name_prefix}-bastion-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
  for_each = toset(var.admin_cidr_blocks)

  security_group_id = aws_security_group.bastion.id
  cidr_ipv4          = each.value
  from_port           = 22
  to_port              = 22
  ip_protocol          = "tcp"
  description          = "SSH from admin CIDR ${each.value}"
}

resource "aws_vpc_security_group_egress_rule" "bastion_all" {
  security_group_id = aws_security_group.bastion.id
  cidr_ipv4          = "0.0.0.0/0"
  ip_protocol         = "-1"
  description         = "All outbound"
}

# ---------------------------------------------------------------------------
# App server: only accepts traffic from the ALB (app port) and the bastion
# (SSH for break-glass access). Never accepts traffic directly from the
# internet.
# ---------------------------------------------------------------------------
resource "aws_security_group" "app" {
  name        = "${local.name_prefix}-app-sg"
  description = "App server - traffic from ALB and bastion only"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${local.name_prefix}-app-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                     = var.app_port
  to_port                        = var.app_port
  ip_protocol                    = "tcp"
  description                    = "App port from ALB"
}

resource "aws_vpc_security_group_ingress_rule" "app_ssh_from_bastion" {
  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.bastion.id
  from_port                     = 22
  to_port                        = 22
  ip_protocol                    = "tcp"
  description                    = "SSH from bastion only"
}

resource "aws_vpc_security_group_egress_rule" "app_all" {
  security_group_id = aws_security_group.app.id
  cidr_ipv4          = "0.0.0.0/0"
  ip_protocol         = "-1"
  description         = "All outbound (ECR pull, Secrets Manager, DB)"
}

# ---------------------------------------------------------------------------
# Database: only accepts Postgres traffic from the app server and the
# bastion (for admin access via SSH tunnel / psql from the bastion). Never
# publicly accessible.
# ---------------------------------------------------------------------------
resource "aws_security_group" "db" {
  name        = "${local.name_prefix}-db-sg"
  description = "RDS PostgreSQL - traffic from app server and bastion only"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${local.name_prefix}-db-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = aws_security_group.app.id
  from_port                     = 5432
  to_port                        = 5432
  ip_protocol                    = "tcp"
  description                    = "Postgres from app server"
}

resource "aws_vpc_security_group_ingress_rule" "db_from_bastion" {
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = aws_security_group.bastion.id
  from_port                     = 5432
  to_port                        = 5432
  ip_protocol                    = "tcp"
  description                    = "Postgres from bastion (admin access)"
}

resource "aws_vpc_security_group_egress_rule" "db_all" {
  security_group_id = aws_security_group.db.id
  cidr_ipv4          = "0.0.0.0/0"
  ip_protocol         = "-1"
  description         = "All outbound"
}
