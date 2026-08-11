output "vpc_id" {
  value = module.networking.vpc_id
}

output "public_subnet_ids" {
  value = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.networking.private_subnet_ids
}

output "alb_dns_name" {
  description = "Point your browser/curl here to reach the app once it's deployed."
  value       = module.alb.alb_dns_name
}

output "bastion_public_ip" {
  value = module.bastion.public_ip
}

output "db_endpoint" {
  value = module.rds.db_endpoint
}

output "db_secret_arn" {
  description = "Fetch actual credentials with: aws secretsmanager get-secret-value --secret-id <this arn>"
  value       = module.secrets.secret_arn
}

output "app_storage_bucket" {
  value = module.object_storage.bucket_name
}
