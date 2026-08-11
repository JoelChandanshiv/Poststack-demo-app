resource "aws_codedeploy_app" "app" {
  name             = "${local.name_prefix}"
  compute_platform = "Server" # EC2/on-premises, not ECS or Lambda

  tags = merge(var.tags, { Name = local.name_prefix })
}

resource "aws_codedeploy_deployment_group" "app" {
  app_name              = aws_codedeploy_app.app.name
  deployment_group_name = "${local.name_prefix}-group"
  service_role_arn      = aws_iam_role.codedeploy.arn

  deployment_config_name = "CodeDeployDefault.AllAtOnce" # single instance in dev - nothing to roll gradually across

  ec2_tag_filter {
    key   = "Name"
    type  = "KEY_AND_VALUE"
    value = var.app_server_name_tag
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  tags = var.tags
}
