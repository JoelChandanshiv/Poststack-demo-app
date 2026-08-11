output "alerts_topic_arn" {
  description = "Reused by the drift-detection module (platform/drift-detection) so drift alerts land in the same place as infra alarms."
  value       = aws_sns_topic.alerts.arn
}

output "app_log_group_name" {
  value = aws_cloudwatch_log_group.app.name
}
