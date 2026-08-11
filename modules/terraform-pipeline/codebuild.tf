resource "aws_codebuild_project" "plan" {
  name         = "${local.name_prefix}-tf-plan"
  service_role = aws_iam_role.codebuild_plan.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type            = "LINUX_CONTAINER"

    environment_variable {
      name  = "TF_ENV"
      value = var.environment
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "ci/buildspec-tf-plan.yml"
  }

  tags = merge(var.tags, { Name = "${local.name_prefix}-tf-plan" })
}

resource "aws_codebuild_project" "apply" {
  name         = "${local.name_prefix}-tf-apply"
  service_role = aws_iam_role.codebuild_apply.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type            = "LINUX_CONTAINER"

    environment_variable {
      name  = "TF_ENV"
      value = var.environment
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "ci/buildspec-tf-apply.yml"
  }

  tags = merge(var.tags, { Name = "${local.name_prefix}-tf-apply" })
}
