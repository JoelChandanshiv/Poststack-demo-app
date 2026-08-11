output "db_instance_id" {
  value = aws_db_instance.this.id
}

output "db_instance_arn" {
  value = aws_db_instance.this.arn
}

output "db_endpoint" {
  description = "host:port connection endpoint."
  value       = aws_db_instance.this.endpoint
}

output "db_address" {
  description = "Host only, no port."
  value       = aws_db_instance.this.address
}

output "db_port" {
  value = aws_db_instance.this.port
}
