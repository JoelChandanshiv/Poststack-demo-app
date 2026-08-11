data "aws_iam_policy_document" "eventbridge_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eventbridge_start_pipeline" {
  name               = "${var.project_name}-drift-eventbridge-role"
  assume_role_policy = data.aws_iam_policy_document.eventbridge_assume.json
}

data "aws_iam_policy_document" "eventbridge_start_pipeline" {
  statement {
    actions   = ["codepipeline:StartPipelineExecution"]
    resources = [for k in keys(local.envs) : aws_codepipeline.drift_check[k].arn]
  }
}

resource "aws_iam_role_policy" "eventbridge_start_pipeline" {
  name   = "${var.project_name}-drift-eventbridge-policy"
  role   = aws_iam_role.eventbridge_start_pipeline.id
  policy = data.aws_iam_policy_document.eventbridge_start_pipeline.json
}

resource "aws_cloudwatch_event_rule" "drift_schedule" {
  for_each = local.envs

  name                = "${var.project_name}-${each.key}-drift-schedule"
  schedule_expression = each.value.schedule
}

resource "aws_cloudwatch_event_target" "drift_schedule" {
  for_each = local.envs

  rule      = aws_cloudwatch_event_rule.drift_schedule[each.key].name
  arn       = aws_codepipeline.drift_check[each.key].arn
  role_arn  = aws_iam_role.eventbridge_start_pipeline.arn
}
