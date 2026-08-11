data "aws_iam_policy_document" "codebuild_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "codepipeline_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

# One role per environment so state-bucket access stays scoped to that
# environment's key prefix, same reasoning as the plan role in
# modules/terraform-pipeline.
resource "aws_iam_role" "drift_check" {
  for_each = local.envs

  name               = "${var.project_name}-${each.key}-drift-check-role"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume.json
}

resource "aws_iam_role_policy_attachment" "drift_check_readonly" {
  for_each = local.envs

  role       = aws_iam_role.drift_check[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

data "aws_iam_policy_document" "drift_check_state_access" {
  for_each = local.envs

  statement {
    sid     = "StateBucketAccess"
    actions = ["s3:GetObject", "s3:ListBucket"]
    resources = [
      "arn:aws:s3:::${var.state_bucket_name}",
      "arn:aws:s3:::${var.state_bucket_name}/${each.key}/*",
    ]
  }

  statement {
    sid       = "StateKmsAccess"
    actions   = ["kms:Decrypt"]
    resources = [var.state_bucket_kms_key_arn]
  }

  statement {
    sid       = "DriftBucketAccess"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${aws_s3_bucket.drift.arn}/*"]
  }

  statement {
    sid = "Logs"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${var.project_name}-${each.key}-drift-check"]
  }
}

resource "aws_iam_role_policy" "drift_check_state" {
  for_each = local.envs

  name   = "${var.project_name}-${each.key}-drift-check-state"
  role   = aws_iam_role.drift_check[each.key].id
  policy = data.aws_iam_policy_document.drift_check_state_access[each.key].json
}

resource "aws_iam_role" "drift_pipeline" {
  name               = "${var.project_name}-drift-codepipeline-role"
  assume_role_policy = data.aws_iam_policy_document.codepipeline_assume.json
}

data "aws_iam_policy_document" "drift_pipeline_policy" {
  statement {
    sid       = "ArtifactBucket"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:GetBucketVersioning"]
    resources = [aws_s3_bucket.drift.arn, "${aws_s3_bucket.drift.arn}/*"]
  }

  statement {
    sid       = "UseGithubConnection"
    actions   = ["codestar-connections:UseConnection"]
    resources = [var.github_connection_arn]
  }

  statement {
    sid       = "RunCodeBuild"
    actions   = ["codebuild:StartBuild", "codebuild:BatchGetBuilds"]
    resources = [for k in keys(local.envs) : aws_codebuild_project.drift_check[k].arn]
  }
}

resource "aws_iam_role_policy" "drift_pipeline" {
  name   = "${var.project_name}-drift-codepipeline-policy"
  role   = aws_iam_role.drift_pipeline.id
  policy = data.aws_iam_policy_document.drift_pipeline_policy.json
}
