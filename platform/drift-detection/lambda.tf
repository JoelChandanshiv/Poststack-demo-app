data "archive_file" "drift_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/drift_check.py"
  output_path = "${path.module}/lambda/drift_check.zip"
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "drift_lambda" {
  name               = "${var.project_name}-drift-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "drift_lambda_policy" {
  statement {
    sid = "Logs"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"]
  }

  statement {
    sid       = "ReadReports"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.drift.arn}/*"]
  }

  statement {
    sid       = "PublishAlerts"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.drift_alerts.arn]
  }
}

resource "aws_iam_role_policy" "drift_lambda" {
  name   = "${var.project_name}-drift-lambda-policy"
  role   = aws_iam_role.drift_lambda.id
  policy = data.aws_iam_policy_document.drift_lambda_policy.json
}

resource "aws_lambda_function" "drift_check" {
  function_name = "${var.project_name}-drift-check-notifier"
  role          = aws_iam_role.drift_lambda.arn
  handler       = "drift_check.handler"
  runtime       = "python3.12"
  timeout       = 30

  filename         = data.archive_file.drift_lambda.output_path
  source_code_hash = data.archive_file.drift_lambda.output_base64sha256

  environment {
    variables = {
      REPORT_BUCKET = aws_s3_bucket.drift.id
      SNS_TOPIC_ARN = aws_sns_topic.drift_alerts.arn
    }
  }
}

resource "aws_cloudwatch_event_rule" "pipeline_state_change" {
  name = "${var.project_name}-drift-pipeline-state-change"

  event_pattern = jsonencode({
    source      = ["aws.codepipeline"]
    detail-type = ["CodePipeline Pipeline Execution State Change"]
    detail = {
      pipeline = [for k in keys(local.envs) : "${var.project_name}-${k}-drift-check"]
      state    = ["SUCCEEDED", "FAILED"]
    }
  })
}

resource "aws_cloudwatch_event_target" "pipeline_state_change" {
  rule = aws_cloudwatch_event_rule.pipeline_state_change.name
  arn  = aws_lambda_function.drift_check.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.drift_check.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.pipeline_state_change.arn
}
