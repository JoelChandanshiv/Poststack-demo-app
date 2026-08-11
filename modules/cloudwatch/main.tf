locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

resource "aws_sns_topic" "alerts" {
  name = "${local.name_prefix}-alerts"

  tags = merge(var.tags, { Name = "${local.name_prefix}-alerts" })
}

resource "aws_sns_topic_subscription" "email" {
  count = var.alarm_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/${var.project_name}/${var.environment}/app"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, { Name = "${local.name_prefix}-app-logs" })
}

resource "aws_cloudwatch_metric_alarm" "app_cpu_high" {
  alarm_name          = "${local.name_prefix}-app-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods   = 3
  metric_name           = "CPUUtilization"
  namespace              = "AWS/EC2"
  period                  = 300
  statistic                = "Average"
  threshold                = 80
  alarm_description        = "App server CPU above 80% for 15 minutes"
  alarm_actions             = [aws_sns_topic.alerts.arn]
  ok_actions                 = [aws_sns_topic.alerts.arn]

  dimensions = {
    InstanceId = var.app_instance_id
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "db_cpu_high" {
  alarm_name          = "${local.name_prefix}-db-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods   = 3
  metric_name           = "CPUUtilization"
  namespace              = "AWS/RDS"
  period                  = 300
  statistic                = "Average"
  threshold                = 80
  alarm_description        = "RDS CPU above 80% for 15 minutes"
  alarm_actions             = [aws_sns_topic.alerts.arn]
  ok_actions                 = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = var.db_instance_id
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "db_storage_low" {
  alarm_name          = "${local.name_prefix}-db-storage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods   = 1
  metric_name           = "FreeStorageSpace"
  namespace              = "AWS/RDS"
  period                  = 300
  statistic                = "Average"
  threshold                = 2147483648 # 2 GiB in bytes
  alarm_description        = "RDS free storage below 2 GiB"
  alarm_actions             = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = var.db_instance_id
  }

  tags = var.tags
}
