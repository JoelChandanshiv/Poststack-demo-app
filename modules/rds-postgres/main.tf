locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

resource "aws_db_subnet_group" "this" {
  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.tags, { Name = "${local.name_prefix}-db-subnet-group" })
}

resource "aws_db_instance" "this" {
  identifier = "${local.name_prefix}-postgres"

  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.db_security_group_id]

  # Never reachable from outside the VPC, regardless of subnet routing.
  publicly_accessible = false

  multi_az                = var.multi_az
  backup_retention_period = var.backup_retention_period
  backup_window            = "17:00-18:00" # 22:30-23:30 IST, low-traffic window
  maintenance_window       = "sun:18:30-sun:19:30" # 00:00-01:00 IST Monday

  deletion_protection = var.deletion_protection
  skip_final_snapshot = var.skip_final_snapshot
  # Deliberately a fixed name, not timestamp()-based — a timestamp here
  # would make this attribute change on every single plan/apply, which
  # breaks idempotency for no benefit (this identifier is only ever read
  # at the moment of a real `terraform destroy`, and AWS would reject a
  # second destroy reusing the same name anyway, so uniqueness-at-destroy-
  # time is a non-issue in practice).
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${local.name_prefix}-postgres-final"

  # Applies patches during the maintenance window instead of immediately —
  # avoids an unplanned restart mid-apply for an unrelated change.
  apply_immediately = var.environment == "dev"

  tags = merge(var.tags, { Name = "${local.name_prefix}-postgres" })

  lifecycle {
    # The master password is set at creation and managed by Terraform via
    # Secrets Manager going forward — ignore drift on this specific
    # attribute so an out-of-band rotation (if ever done manually in an
    # emergency) doesn't fight with Terraform on every plan. Rotation
    # should still normally happen by changing var.db_password through
    # Terraform, not manually.
    ignore_changes = [password]
  }
}
