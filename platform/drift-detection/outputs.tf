output "drift_alerts_topic_arn" {
  value = aws_sns_topic.drift_alerts.arn
}

output "drift_pipeline_names" {
  value = { for k, v in aws_codepipeline.drift_check : k => v.name }
}
