output "app_server_role_arn" {
  value = aws_iam_role.app_server.arn
}

output "app_server_instance_profile_name" {
  value = aws_iam_instance_profile.app_server.name
}

output "bastion_role_arn" {
  value = aws_iam_role.bastion.arn
}

output "bastion_instance_profile_name" {
  value = aws_iam_instance_profile.bastion.name
}
