locals {
  # Building the stage list as data lets the approval stage be inserted
  # conditionally without duplicating the whole aws_codepipeline resource
  # for the require_manual_approval=true/false cases.
  stages = concat(
    [
      {
        name = "Source"
        actions = [
          {
            name             = "Source"
            category         = "Source"
            owner            = "AWS"
            provider         = "CodeStarSourceConnection"
            version          = "1"
            input_artifacts  = []
            output_artifacts = ["source_output"]
            configuration = {
              ConnectionArn    = var.github_connection_arn
              FullRepositoryId = var.github_full_repository_id
              BranchName       = var.branch_name
              DetectChanges    = "true"
            }
          }
        ]
      },
      {
        name = "Plan"
        actions = [
          {
            name             = "TerraformPlan"
            category         = "Build"
            owner            = "AWS"
            provider         = "CodeBuild"
            version          = "1"
            input_artifacts  = ["source_output"]
            output_artifacts = ["plan_output"]
            configuration = {
              ProjectName = aws_codebuild_project.plan.name
            }
          }
        ]
      }
    ],
    var.require_manual_approval ? [
      {
        name = "Approve"
        actions = [
          {
            name             = "ManualApproval"
            category         = "Approval"
            owner            = "AWS"
            provider         = "Manual"
            version          = "1"
            input_artifacts  = []
            output_artifacts = []
            configuration = {
              NotificationArn = aws_sns_topic.approvals[0].arn
              CustomData      = "Review the Terraform plan for ${var.environment} (see the TerraformPlan build logs / plan_output artifact) before approving apply."
            }
          }
        ]
      }
    ] : [],
    [
      {
        name = "Apply"
        actions = [
          {
            name             = "TerraformApply"
            category         = "Build"
            owner            = "AWS"
            provider         = "CodeBuild"
            version          = "1"
            input_artifacts  = ["plan_output"]
            output_artifacts = []
            configuration = {
              ProjectName = aws_codebuild_project.apply.name
            }
          }
        ]
      }
    ]
  )
}

resource "aws_codepipeline" "this" {
  name     = "${local.name_prefix}-tf-pipeline"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    type     = "S3"
    location = aws_s3_bucket.artifacts.id
  }

  dynamic "stage" {
    for_each = local.stages

    content {
      name = stage.value.name

      dynamic "action" {
        for_each = stage.value.actions

        content {
          name             = action.value.name
          category         = action.value.category
          owner            = action.value.owner
          provider         = action.value.provider
          version          = action.value.version
          input_artifacts  = action.value.input_artifacts
          output_artifacts = action.value.output_artifacts
          configuration    = action.value.configuration
        }
      }
    }
  }

  tags = merge(var.tags, { Name = "${local.name_prefix}-tf-pipeline" })
}
