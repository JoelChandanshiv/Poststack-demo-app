resource "aws_codebuild_project" "drift_check" {
  for_each = local.envs

  name         = "${var.project_name}-${each.key}-drift-check"
  service_role = aws_iam_role.drift_check[each.key].arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "TF_ENV"
      value = each.key
    }
    environment_variable {
      name  = "REPORT_BUCKET"
      value = aws_s3_bucket.drift.id
    }
    environment_variable {
      name  = "REPORT_KEY_PREFIX"
      value = "${var.project_name}-${each.key}-drift-check"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "ci/buildspec-drift-check.yml"
  }
}

resource "aws_codepipeline" "drift_check" {
  for_each = local.envs

  name     = "${var.project_name}-${each.key}-drift-check"
  role_arn = aws_iam_role.drift_pipeline.arn

  artifact_store {
    type     = "S3"
    location = aws_s3_bucket.drift.id
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = var.github_connection_arn
        FullRepositoryId = var.github_full_repository_id
        BranchName       = each.value.branch
        # false: a push to this branch does NOT auto-trigger this pipeline.
        # This pipeline only runs on the EventBridge schedule below (or a
        # manual StartPipelineExecution) - it checks for drift against
        # whatever is currently in the branch, it isn't meant to fire on
        # every commit the way the real deploy pipeline is.
        DetectChanges = "false"
      }
    }
  }

  stage {
    name = "CheckDrift"

    action {
      name            = "TerraformPlanOnly"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["source_output"]

      configuration = {
        ProjectName = aws_codebuild_project.drift_check[each.key].name
      }
    }
  }
}
