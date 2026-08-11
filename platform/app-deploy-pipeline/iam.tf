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

data "aws_iam_policy_document" "codedeploy_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }
  }
}

# ---------------------------------------------------------------------------
# CodePipeline role - needs access to BOTH regions' artifact buckets/keys,
# since it orchestrates a cross-region pipeline.
# ---------------------------------------------------------------------------
resource "aws_iam_role" "codepipeline" {
  name               = "${local.name_prefix}-codepipeline-role"
  assume_role_policy = data.aws_iam_policy_document.codepipeline_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "codepipeline_policy" {
  statement {
    sid = "ArtifactBucketsBothRegions"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:GetBucketVersioning",
    ]
    resources = [
      aws_s3_bucket.artifacts_primary.arn, "${aws_s3_bucket.artifacts_primary.arn}/*",
      aws_s3_bucket.artifacts_connection_region.arn, "${aws_s3_bucket.artifacts_connection_region.arn}/*",
    ]
  }

  statement {
    sid       = "KmsBothRegions"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
    resources = [aws_kms_key.artifacts_primary.arn, aws_kms_key.artifacts_connection_region.arn]
  }

  statement {
    sid       = "UseGithubConnection"
    actions   = ["codestar-connections:UseConnection"]
    resources = [var.github_connection_arn]
  }

  statement {
    sid       = "RunCodeBuild"
    actions   = ["codebuild:StartBuild", "codebuild:BatchGetBuilds"]
    resources = [aws_codebuild_project.app_build.arn]
  }

  statement {
    sid = "RunCodeDeploy"
    actions = [
      "codedeploy:CreateDeployment",
      "codedeploy:GetDeployment",
      "codedeploy:GetDeploymentConfig",
      "codedeploy:GetApplication",
      "codedeploy:GetApplicationRevision",
      "codedeploy:RegisterApplicationRevision",
    ]
    resources = [
      aws_codedeploy_app.app.arn,
      aws_codedeploy_deployment_group.app.arn,
      "arn:aws:codedeploy:${var.aws_region}:${data.aws_caller_identity.current.account_id}:deploymentconfig:*",
    ]
  }
}

resource "aws_iam_role_policy" "codepipeline" {
  name   = "${local.name_prefix}-codepipeline-policy"
  role   = aws_iam_role.codepipeline.id
  policy = data.aws_iam_policy_document.codepipeline_policy.json
}

# ---------------------------------------------------------------------------
# CodeBuild role - builds+pushes the image. Only needs the primary region's
# artifact bucket (it runs in ap-south-2), plus scoped ECR push permissions.
# ---------------------------------------------------------------------------
resource "aws_iam_role" "codebuild" {
  name               = "${local.name_prefix}-codebuild-role"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "codebuild_policy" {
  statement {
    sid       = "ArtifactBucket"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${aws_s3_bucket.artifacts_primary.arn}/*"]
  }

  statement {
    sid       = "ArtifactKms"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [aws_kms_key.artifacts_primary.arn]
  }

  statement {
    sid       = "EcrAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"] # GetAuthorizationToken has no resource-level scoping in ECR's API
  }

  statement {
    sid = "EcrPush"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
    ]
    resources = [var.ecr_repository_arn]
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

resource "aws_iam_role_policy" "codebuild" {
  name   = "${local.name_prefix}-codebuild-policy"
  role   = aws_iam_role.codebuild.id
  policy = data.aws_iam_policy_document.codebuild_policy.json
}

# ---------------------------------------------------------------------------
# CodeDeploy service role - standard AWS-managed policy, this is the
# documented, expected way to grant CodeDeploy the EC2-tag-discovery and
# deployment-orchestration permissions it needs.
# ---------------------------------------------------------------------------
resource "aws_iam_role" "codedeploy" {
  name               = "${local.name_prefix}-codedeploy-role"
  assume_role_policy = data.aws_iam_policy_document.codedeploy_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "codedeploy" {
  role       = aws_iam_role.codedeploy.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

# ---------------------------------------------------------------------------
# Extends the EXISTING app-server IAM role (created by modules/iam, applied
# via environments/<env>, a different Terraform state than this one) so the
# CodeDeploy agent running on that instance can pull the deployment
# revision from the primary-region artifact bucket. This is a normal,
# supported pattern - one state file adding a scoped policy to a role a
# different state file owns - not a circular dependency, since the role
# already exists by the time this config is applied.
# ---------------------------------------------------------------------------
data "aws_iam_role" "app_server" {
  name = var.app_server_role_name
}

data "aws_iam_policy_document" "app_server_codedeploy_artifact_access" {
  statement {
    sid = "ReadDeploymentArtifact"
    # GetObjectVersion is required in addition to GetObject - the artifact
    # bucket has versioning enabled, and CodeDeploy fetches the revision by
    # a specific version ID (visible in the revision location's
    # ?versionId=... query param), which is a distinct IAM action from
    # plain GetObject even though it sounds redundant.
    actions   = ["s3:GetObject", "s3:GetObjectVersion"]
    resources = ["${aws_s3_bucket.artifacts_primary.arn}/*"]
  }

  statement {
    sid       = "DecryptDeploymentArtifact"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.artifacts_primary.arn]
  }
}

resource "aws_iam_role_policy" "app_server_codedeploy_artifact_access" {
  name   = "${local.name_prefix}-app-server-artifact-access"
  role   = data.aws_iam_role.app_server.id
  policy = data.aws_iam_policy_document.app_server_codedeploy_artifact_access.json
}
