resource "aws_codebuild_project" "app_build" {
  name         = "${local.name_prefix}-build"
  service_role = aws_iam_role.codebuild.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type         = "LINUX_CONTAINER"

    # Required for `docker build` to work at all inside CodeBuild - without
    # this, the build container has no Docker daemon available and every
    # docker command fails immediately.
    privileged_mode = true

    environment_variable {
      name  = "ECR_REPOSITORY_URL"
      value = var.ecr_repository_url
    }
    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "ci/buildspec-app.yml"
  }

  tags = merge(var.tags, { Name = "${local.name_prefix}-build" })
}
