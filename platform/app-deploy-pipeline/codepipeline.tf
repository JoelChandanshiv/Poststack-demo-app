resource "aws_codepipeline" "app_deploy" {
  # AWS requires the Source action to be in the SAME region as the
  # pipeline itself - cross-region actions are only supported for stages
  # AFTER Source. Since the GitHub connection only exists in
  # var.connection_region, the pipeline resource itself has to be created
  # there too. Build and Deploy become the cross-region actions instead,
  # explicitly pinned to var.aws_region (ap-south-2) below, since that's
  # where the CodeBuild project and CodeDeploy app/group actually live.
  provider = aws.connection_region

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

      # No region override here - Source must match the pipeline's own
      # region (var.connection_region, set via the provider block above),
      # AWS rejects any attempt to pin Source to a different region.

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

      # Cross-region: the CodeBuild project lives in ap-south-2, while the
      # pipeline itself is homed in ap-south-1 (see provider on the
      # aws_codepipeline resource above).
      region = var.aws_region

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

      # Cross-region: CodeDeploy and the target EC2 instance both live in
      # ap-south-2 (a hard requirement - see the note at the top of
      # main.tf), while the pipeline itself is homed in ap-south-1.
      region = var.aws_region

      configuration = {
        ApplicationName     = aws_codedeploy_app.app.name
        DeploymentGroupName = aws_codedeploy_deployment_group.app.deployment_group_name
      }
    }
  }

  tags = merge(var.tags, { Name = "${local.name_prefix}-pipeline" })
}
