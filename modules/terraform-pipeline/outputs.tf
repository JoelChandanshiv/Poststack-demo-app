output "pipeline_name" {
  value = aws_codepipeline.this.name
}

output "artifact_bucket_name" {
  value = aws_s3_bucket.artifacts.id
}

output "plan_project_name" {
  value = aws_codebuild_project.plan.name
}

output "apply_project_name" {
  value = aws_codebuild_project.apply.name
}
