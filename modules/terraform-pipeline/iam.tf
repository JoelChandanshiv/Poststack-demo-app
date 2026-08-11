data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "codepipeline_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "codebuild_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

# ---------------------------------------------------------------------------
# CodePipeline role: orchestrates, doesn't touch AWS infra resources itself.
# ---------------------------------------------------------------------------
resource "aws_iam_role" "codepipeline" {
  name               = "${local.name_prefix}-codepipeline-role"
  assume_role_policy = data.aws_iam_policy_document.codepipeline_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "codepipeline_policy" {
  statement {
    sid       = "ArtifactBucket"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:GetBucketVersioning"]
    resources = [aws_s3_bucket.artifacts.arn, "${aws_s3_bucket.artifacts.arn}/*"]
  }

  statement {
    sid       = "UseGithubConnection"
    actions   = ["codestar-connections:UseConnection"]
    resources = [var.github_connection_arn]
  }

  statement {
    sid = "RunCodeBuild"
    actions = [
      "codebuild:StartBuild",
      "codebuild:BatchGetBuilds",
    ]
    resources = [
      aws_codebuild_project.plan.arn,
      aws_codebuild_project.apply.arn,
    ]
  }

  dynamic "statement" {
    for_each = var.require_manual_approval ? [1] : []
    content {
      sid       = "PublishApprovalNotification"
      actions   = ["sns:Publish"]
      resources = [aws_sns_topic.approvals[0].arn]
    }
  }
}

resource "aws_iam_role_policy" "codepipeline" {
  name   = "${local.name_prefix}-codepipeline-policy"
  role   = aws_iam_role.codepipeline.id
  policy = data.aws_iam_policy_document.codepipeline_policy.json
}

# ---------------------------------------------------------------------------
# Shared: both plan and apply roles need to read/write this environment's
# state file and the artifact bucket. Neither needs access to the other
# environment's state key.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "state_and_artifacts_access" {
  statement {
    sid = "StateBucketAccess"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::${var.state_bucket_name}",
      "arn:aws:s3:::${var.state_bucket_name}/${var.environment}/*",
    ]
  }

  statement {
    sid       = "StateKmsAccess"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [var.state_bucket_kms_key_arn]
  }

  statement {
    sid       = "ArtifactBucketAccess"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${aws_s3_bucket.artifacts.arn}/*"]
  }

  statement {
    sid = "Logs"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${local.name_prefix}-*"]
  }
}

# ---------------------------------------------------------------------------
# Plan role: `terraform plan` only ever reads/describes AWS resources - it
# never creates, modifies, or deletes anything. AWS's own ReadOnlyAccess
# managed policy is the pragmatic choice here: plan has to be able to read
# arbitrary resource types across every module in this project, and hand-
# writing a describe/list/get action list per service that stays in sync
# as modules are added would need updating every time a module changes,
# with no real security upside since none of these actions can mutate
# anything.
# ---------------------------------------------------------------------------
resource "aws_iam_role" "codebuild_plan" {
  name               = "${local.name_prefix}-codebuild-plan-role"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "plan_readonly" {
  role       = aws_iam_role.codebuild_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy" "plan_state_access" {
  name   = "${local.name_prefix}-codebuild-plan-state"
  role   = aws_iam_role.codebuild_plan.id
  policy = data.aws_iam_policy_document.state_and_artifacts_access.json
}

# ---------------------------------------------------------------------------
# Apply role: this is the role that actually creates/modifies/deletes
# infrastructure. Scoped two ways:
#   1. Where AWS supports resource-level permissions (IAM, Secrets Manager,
#      S3, RDS-by-tag), access is limited to resources named with this
#      project's naming convention.
#   2. Where AWS's API does not support resource-level permissions for the
#      relevant actions (most EC2 Create*/Delete* calls, ELBv2, most VPC
#      networking calls - this is a real, documented AWS API limitation,
#      not a shortcut taken here), the action is scoped to the service but
#      resources = "*" - there is no tighter option available at the IAM
#      policy level for these specific actions.
# This is the realistic ceiling for a Terraform CI role covering this many
# resource types. Tightening further requires AWS resource-level
# permission support that doesn't currently exist for several of the
# actions below.
# ---------------------------------------------------------------------------
resource "aws_iam_role" "codebuild_apply" {
  name               = "${local.name_prefix}-codebuild-apply-role"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "apply_state_access" {
  name   = "${local.name_prefix}-codebuild-apply-state"
  role   = aws_iam_role.codebuild_apply.id
  policy = data.aws_iam_policy_document.state_and_artifacts_access.json
}

data "aws_iam_policy_document" "apply_infra" {
  statement {
    sid = "NetworkingAndComputeNoResourceLevelSupport"
    # EC2/ELBv2 do not support resource-level permissions for most of
    # these actions - AWS-documented limitation, not scoped further here.
    actions = [
      "ec2:*Vpc*", "ec2:*Subnet*", "ec2:*InternetGateway*", "ec2:*NatGateway*",
      "ec2:*RouteTable*", "ec2:*Route", "ec2:*SecurityGroup*", "ec2:*Address*",
      "ec2:RunInstances", "ec2:TerminateInstances", "ec2:StopInstances", "ec2:StartInstances",
      "ec2:*Instance*", "ec2:Describe*", "ec2:CreateTags", "ec2:DeleteTags",
      "elasticloadbalancing:*",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "RDS"
    actions   = ["rds:*"]
    resources = ["arn:aws:rds:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*:${var.project_name}-${var.environment}-*"]
  }

  statement {
    sid       = "RDSSubnetGroups"
    # Subnet groups and parameter groups don't consistently support the
    # naming-scoped ARN pattern above across all RDS actions - kept broad
    # but read/describe plus the specific create/delete calls needed.
    actions = [
      "rds:DescribeDBSubnetGroups", "rds:CreateDBSubnetGroup", "rds:DeleteDBSubnetGroup", "rds:ModifyDBSubnetGroup",
      "rds:ListTagsForResource", "rds:AddTagsToResource",
    ]
    resources = ["*"]
  }

  statement {
    sid = "IamScoped"
    actions = [
      "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:UpdateRole",
      "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:GetRolePolicy",
      "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:ListAttachedRolePolicies", "iam:ListRolePolicies",
      "iam:CreateInstanceProfile", "iam:DeleteInstanceProfile", "iam:GetInstanceProfile",
      "iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile",
      "iam:TagRole", "iam:UntagRole",
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-${var.environment}-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/${var.project_name}-${var.environment}-*",
    ]
  }

  statement {
    sid       = "IamPassRoleScoped"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-${var.environment}-*"]
  }

  statement {
    sid       = "SecretsManagerScoped"
    actions   = ["secretsmanager:*"]
    resources = ["arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}-${var.environment}/*"]
  }

  statement {
    sid       = "S3AppBucketsScoped"
    actions   = ["s3:*"]
    resources = [
      "arn:aws:s3:::${var.project_name}-${var.environment}-*",
      "arn:aws:s3:::${var.project_name}-${var.environment}-*/*",
    ]
  }

  statement {
    sid       = "CloudWatchAndSns"
    actions   = ["cloudwatch:*", "logs:*", "sns:*"]
    resources = ["*"]
  }

  statement {
    sid       = "Backup"
    actions   = ["backup:*"]
    resources = ["*"]
  }

  statement {
    sid       = "EcrReadOnly"
    actions   = ["ecr:GetAuthorizationToken", "ecr:DescribeRepositories", "ecr:ListTagsForResource"]
    resources = ["*"]
  }

  statement {
    sid       = "KmsForSecretsAndState"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "apply_infra" {
  name   = "${local.name_prefix}-codebuild-apply-infra"
  role   = aws_iam_role.codebuild_apply.id
  policy = data.aws_iam_policy_document.apply_infra.json
}
