output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets, in the same order as availability_zones."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets, in the same order as availability_zones."
  value       = aws_subnet.private[*].id
}

output "availability_zones" {
  description = "AZs used, in the same order as the subnet ID lists above."
  value       = var.availability_zones
}

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateway(s) created."
  value       = aws_nat_gateway.this[*].id
}

output "public_route_table_id" {
  description = "ID of the shared public route table."
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "IDs of the private route tables, one per AZ."
  value       = aws_route_table.private[*].id
}
