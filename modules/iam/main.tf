locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# ---------------------------------------------------------------------------
# App server role: ECR pull (scoped to specific repos), Secrets Manager read
# (scoped to specific secrets), SSM core (secondary access path + enables
# the CodeDeploy agent to be managed without SSH), and CloudWatch Agent
# permissions for shipping logs/metrics.
# ---------------------------------------------------------------------------
resource "aws_iam_role" "app_server" {
  name               = "${local.name_prefix}-app-server-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = merge(var.tags, { Name = "${local.name_prefix}-app-server-role" })
}

# ECR GetAuthorizationToken is not resource-scopable — it must be "*" per
# AWS's own API design (there is no per-repo variant of this specific call).
# Everything else below IS scoped to the specific repo ARNs passed in.
data "aws_iam_policy_document" "app_server_ecr" {
  statement {
    sid       = "ECRAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "ECRPull"
    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchCheckLayerAvailability",
    ]
    resources = var.ecr_repository_arns
  }
}

resource "aws_iam_role_policy" "app_server_ecr" {
  name   = "${local.name_prefix}-app-server-ecr"
  role   = aws_iam_role.app_server.id
  policy = data.aws_iam_policy_document.app_server_ecr.json
}

data "aws_iam_policy_document" "app_server_secrets" {
  statement {
    sid       = "SecretsRead"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = var.secret_arns
  }

  dynamic "statement" {
    for_each = length(var.kms_key_arns) > 0 ? [1] : []
    content {
      sid       = "SecretsKmsDecrypt"
      actions   = ["kms:Decrypt"]
      resources = var.kms_key_arns
    }
  }
}

resource "aws_iam_role_policy" "app_server_secrets" {
  name   = "${local.name_prefix}-app-server-secrets"
  role   = aws_iam_role.app_server.id
  policy = data.aws_iam_policy_document.app_server_secrets.json
}

resource "aws_iam_role_policy_attachment" "app_server_ssm" {
  role       = aws_iam_role.app_server.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "app_server_cloudwatch_agent" {
  role       = aws_iam_role.app_server.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# ---------------------------------------------------------------------------
# Bedrock InvokeModel - scoped to the specific model(s) the app uses, not a
# blanket "bedrock:*" grant. Foundation model ARNs have no account ID
# segment (they're AWS-owned, shared public resources, not something this
# account creates) - that's expected, not a typo.
#
# NOTE: an IAM grant alone is not sufficient to actually call the model.
# Bedrock separately requires "Model access" to be enabled per model, per
# region, per account - a one-time EULA-acceptance step that, as far as
# I'm aware, still has to be done in the Console (Bedrock -> Model access),
# not via Terraform/CLI. This is the same category of unavoidable manual
# step as the GitHub connection OAuth authorization elsewhere in this
# project - flagging it here rather than assuming it's automatable.
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# Bedrock InvokeModel - using the "global" cross-region inference profile
# for Amazon Nova 2 Lite, confirmed via `aws bedrock list-inference-profiles
# --region ap-south-1` to be real and active in this account. The profile
# itself lives in ap-south-1 (var.bedrock_region), not ap-south-2
# (var.aws_region, used everywhere else in this project) - the app server
# calls out to it as a normal cross-region API call.
#
# NOTE: as before, an IAM grant alone is not sufficient - Bedrock Model
# Access must also be enabled for this model in the Console (see
# app/README.md), separate from this policy.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "app_server_bedrock" {
  statement {
    sid     = "BedrockInvokeInferenceProfile"
    actions = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
    resources = [
      for profile_id in var.bedrock_inference_profile_ids :
      "arn:aws:bedrock:${var.bedrock_region}:${data.aws_caller_identity.current.account_id}:inference-profile/${profile_id}"
    ]
  }

  statement {
    sid       = "BedrockInvokeUnderlyingModel"
    actions   = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
    resources = var.bedrock_underlying_model_arns
  }
}

resource "aws_iam_role_policy" "app_server_bedrock" {
  name   = "${local.name_prefix}-app-server-bedrock"
  role   = aws_iam_role.app_server.id
  policy = data.aws_iam_policy_document.app_server_bedrock.json
}

resource "aws_iam_instance_profile" "app_server" {
  name = "${local.name_prefix}-app-server-profile"
  role = aws_iam_role.app_server.name
}

# ---------------------------------------------------------------------------
# Bastion role: SSM only. It does not need ECR or Secrets Manager access —
# admins use it purely as a network hop into the private subnets.
# ---------------------------------------------------------------------------
resource "aws_iam_role" "bastion" {
  name               = "${local.name_prefix}-bastion-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = merge(var.tags, { Name = "${local.name_prefix}-bastion-role" })
}

resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ---------------------------------------------------------------------------
# Lets the bastion's own identity be used as a CALLER to start/manage SSM
# sessions to other instances in this project - distinct from
# AmazonSSMManagedInstanceCore above, which only makes the bastion itself
# a valid session TARGET. Both were needed; only the target half existed
# before, which is what caused the earlier AccessDeniedException on
# ssm:TerminateSession.
#
# Scoped by the Project tag rather than a specific instance ARN - hardcoding
# an instance ID here would create a circular dependency (this iam module
# runs before ec2-app-server, so that instance's ARN doesn't exist yet when
# this policy would need it), and tag-based scoping also means the policy
# doesn't need updating if instances are replaced or added.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "bastion_ssm_caller" {
  statement {
    sid       = "DescribeInstancesForSessionLookup"
    actions   = ["ec2:DescribeInstances"]
    resources = ["*"] # DescribeInstances does not support resource-level scoping
  }

  statement {
    sid     = "StartSessionToProjectTaggedInstances"
    actions = ["ssm:StartSession"]
    resources = [
      "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:instance/*",
      "arn:aws:ssm:${var.aws_region}::document/SSM-SessionManagerRunShell",
    ]

    condition {
      test     = "StringEquals"
      variable = "ssm:resourceTag/Project"
      values   = [var.project_name]
    }
  }

  statement {
    # AWS's documented pattern for letting a caller manage only the
    # sessions they personally started - Session Manager always prefixes
    # session IDs with the caller's identity, so this can't reach anyone
    # else's session even though the resource looks broad.
    sid       = "ManageOwnSessions"
    actions   = ["ssm:TerminateSession", "ssm:ResumeSession"]
    resources = ["arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:session/$${aws:username}-*"]
  }
}

resource "aws_iam_role_policy" "bastion_ssm_caller" {
  name   = "${local.name_prefix}-bastion-ssm-caller"
  role   = aws_iam_role.bastion.id
  policy = data.aws_iam_policy_document.bastion_ssm_caller.json
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${local.name_prefix}-bastion-profile"
  role = aws_iam_role.bastion.name
}
