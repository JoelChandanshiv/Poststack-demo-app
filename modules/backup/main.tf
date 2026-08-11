locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

resource "aws_backup_vault" "this" {
  name = "${local.name_prefix}-backup-vault"

  tags = merge(var.tags, { Name = "${local.name_prefix}-backup-vault" })
}

resource "aws_backup_plan" "this" {
  name = "${local.name_prefix}-backup-plan"

  rule {
    rule_name         = "${local.name_prefix}-daily"
    target_vault_name = aws_backup_vault.this.name
    schedule          = var.schedule

    lifecycle {
      delete_after = var.retention_days
    }
  }

  tags = var.tags
}

data "aws_iam_policy_document" "backup_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "backup" {
  name               = "${local.name_prefix}-backup-role"
  assume_role_policy = data.aws_iam_policy_document.backup_assume_role.json

  tags = var.tags
}

# AWS-managed policy for the Backup service role — this is the standard,
# AWS-documented way to grant Backup permission to snapshot the resources
# in its selection; scoping it further requires reimplementing AWS's own
# managed policy by hand, which reintroduces update risk with no real
# security benefit.
resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_backup_selection" "rds" {
  name         = "${local.name_prefix}-rds-selection"
  plan_id      = aws_backup_plan.this.id
  iam_role_arn = aws_iam_role.backup.arn

  resources = [var.db_instance_arn]
}
