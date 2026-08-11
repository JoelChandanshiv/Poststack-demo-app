locals {
  common_tags = {
    ManagedBy   = "terraform"
    Project     = var.project_name
    Environment = var.environment
  }
}

module "networking" {
  source = "../../modules/networking"

  project_name = var.project_name
  environment  = var.environment

  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs

  # Prod: one NAT Gateway per AZ - no single point of failure for outbound traffic.
  single_nat_gateway = false

  tags = local.common_tags
}

module "security_groups" {
  source = "../../modules/security-groups"

  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.networking.vpc_id
  app_port          = var.app_port
  admin_cidr_blocks = var.admin_cidr_blocks

  tags = local.common_tags
}

module "secrets" {
  source = "../../modules/secrets-manager"

  project_name = var.project_name
  environment  = var.environment
  db_username  = var.db_username

  # Prod secrets get a real recovery window - protects against an
  # accidental `terraform destroy` or a bad apply permanently losing them.
  recovery_window_in_days = 14

  tags = local.common_tags
}

module "iam" {
  source = "../../modules/iam"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  ecr_repository_arns = [var.ecr_repository_arn]
  secret_arns          = [module.secrets.secret_arn]

  tags = local.common_tags
}

module "rds" {
  source = "../../modules/rds-postgres"

  project_name = var.project_name
  environment  = var.environment

  private_subnet_ids   = module.networking.private_subnet_ids
  db_security_group_id = module.security_groups.db_sg_id

  db_name     = var.db_name
  db_username = module.secrets.db_username
  db_password = module.secrets.db_password

  instance_class           = var.db_instance_class
  allocated_storage        = var.db_allocated_storage
  multi_az                 = true
  backup_retention_period  = 30
  deletion_protection      = true
  skip_final_snapshot      = false

  tags = local.common_tags
}

module "bastion" {
  source = "../../modules/bastion"

  project_name = var.project_name
  environment  = var.environment

  public_subnet_id      = module.networking.public_subnet_ids[0]
  bastion_sg_id          = module.security_groups.bastion_sg_id
  instance_profile_name  = module.iam.bastion_instance_profile_name
  instance_type          = "t3.micro"
  ssh_key_name           = var.bastion_ssh_key_name

  tags = local.common_tags
}

module "alb" {
  source = "../../modules/alb"

  project_name = var.project_name
  environment  = var.environment

  vpc_id              = module.networking.vpc_id
  public_subnet_ids   = module.networking.public_subnet_ids
  alb_sg_id           = module.security_groups.alb_sg_id
  app_port            = var.app_port
  health_check_path   = var.health_check_path

  # Prod ALB should not be deletable by accident.
  deletion_protection = true

  tags = local.common_tags
}

module "app_server" {
  source = "../../modules/ec2-app-server"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  private_subnet_id     = module.networking.private_subnet_ids[0]
  app_sg_id             = module.security_groups.app_sg_id
  instance_profile_name = module.iam.app_server_instance_profile_name
  instance_type         = var.app_instance_type
  target_group_arn      = module.alb.target_group_arn
  app_port              = var.app_port
  ssh_key_name          = var.bastion_ssh_key_name

  tags = local.common_tags
}

module "cloudwatch" {
  source = "../../modules/cloudwatch"

  project_name = var.project_name
  environment  = var.environment

  app_instance_id = module.app_server.instance_id
  db_instance_id  = module.rds.db_instance_id
  alarm_email     = var.alarm_email

  log_retention_days = 90

  tags = local.common_tags
}

module "backup" {
  source = "../../modules/backup"

  project_name = var.project_name
  environment  = var.environment

  db_instance_arn = module.rds.db_instance_arn
  retention_days  = 35

  tags = local.common_tags
}

module "object_storage" {
  source = "../../modules/s3-object-storage"

  project_name = var.project_name
  environment  = var.environment

  tags = local.common_tags
}
