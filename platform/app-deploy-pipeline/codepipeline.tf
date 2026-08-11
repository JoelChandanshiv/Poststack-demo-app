resource "aws_codepipeline" "app_deploy" {
  name     = "${local.name_prefix}-pipeline"
  role_arn = aws_iam_role.codepipeline.arn

  # Two artifact_store blocks, each pinned to a region - this is what
  # CodePipeline's cross-region actions feature requires: one store per
  # region that has an action running in it.
  artifact_store {
    region   = var.aws_region
    type     = "S3"
    location = aws_s3_bucket.artifacts_primary.id

    encryption_key {
      id   = aws_kms_key.artifacts_primary.arn
      type = "KMS"
    }
  }

  artifact_store {
    region   = var.connection_region
    type     = "S3"
    location = aws_s3_bucket.artifacts_connection_region.id

    encryption_key {
      id   = aws_kms_key.artifacts_connection_region.arn
      type = "KMS"
    }
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

      # Pinned to the connection's own region - everything else in this
      # pipeline defaults to var.aws_region (the pipeline's primary region)
      # unless explicitly overridden, so only this action needs it.
      region = var.connection_region

      configuration = {
        ConnectionArn    = var.github_connection_arn
        FullRepositoryId = var.github_full_repository_id
        BranchName       = var.branch_name
        DetectChanges    = "true"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "BuildAndPush"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]

      configuration = {
        ProjectName = aws_codebuild_project.app_build.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "DeployToAppServer"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      version         = "1"
      input_artifacts = ["build_output"]

      configuration = {
        ApplicationName     = aws_codedeploy_app.app.name
        DeploymentGroupName = aws_codedeploy_deployment_group.app.deployment_group_name
      }
    }
  }

  tags = merge(var.tags, { Name = "${local.name_prefix}-pipeline" })
}
