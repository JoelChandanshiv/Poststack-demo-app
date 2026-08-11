output "secret_arn" {
  value = aws_secretsmanager_secret.db_credentials.arn
}

output "secret_name" {
  value = aws_secretsmanager_secret.db_credentials.name
}

output "db_username" {
  value = var.db_username
}

output "db_password" {
  value     = random_password.db_master.result
  sensitive = true
}
