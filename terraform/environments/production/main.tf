terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "eap-terraform-state-176899553634"
    key            = "production/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = var.owner
    }
  }
}

# ─── VPC ─────────────────────────────────────────────────────────────────────
module "vpc" {
  source = "../../modules/vpc"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
  public_subnet_cidr_2 = var.public_subnet_cidr_2
  app_subnet_cidr    = var.app_subnet_cidr
  tools_subnet_cidr  = var.tools_subnet_cidr
  data_subnet_cidr   = var.data_subnet_cidr
  availability_zone  = var.availability_zone
  aws_region         = var.aws_region
}

# ─── IAM ─────────────────────────────────────────────────────────────────────
module "iam" {
  source = "../../modules/iam"

  project_name  = var.project_name
  environment   = var.environment
  s3_bucket_arn = module.s3.bucket_arn
}

# ─── Security Groups ─────────────────────────────────────────────────────────
module "security" {
  source = "../../modules/security"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
  vpc_cidr     = var.vpc_cidr
  bastion_ip   = var.bastion_ip
  your_ip_cidr = var.your_ip_cidr
}

# ─── S3 ──────────────────────────────────────────────────────────────────────
module "s3" {
  source = "../../modules/s3"

  project_name = var.project_name
  environment  = var.environment
}

# ─── ALB ─────────────────────────────────────────────────────────────────────
module "alb" {
  source = "../../modules/alb"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  public_subnet_id      = module.vpc.public_subnet_id 
  public_subnet_2_id = module.vpc.public_subnet_2_id
  alb_security_group_id = module.security.alb_sg_id
  certificate_arn       = var.acm_certificate_arn
  s3_logs_bucket        = module.s3.bucket_id
  health_check_path     = var.health_check_path

  # Add these two — they were missing
  domain_name       = var.domain_name              # "gitea.samadov.xyz"
  route53_zone_name = "samadov.xyz"                # apex domain — must match your hosted zone exactly
}

# ─── Compute ─────────────────────────────────────────────────────────────────
module "compute" {
  source = "../../modules/compute"

  project_name           = var.project_name
  environment            = var.environment
  aws_region             = var.aws_region
  key_name               = var.key_name
  app_subnet_id          = module.vpc.app_subnet_id
  public_subnet_id       = module.vpc.public_subnet_id
  tools_subnet_id        = module.vpc.tools_subnet_id
  data_subnet_id         = module.vpc.data_subnet_id
  app_sg_id              = module.security.app_sg_id
  tools_sg_id            = module.security.tools_sg_id
  db_sg_id               = module.security.db_sg_id
  bastion_sg_id          = module.security.bastion_sg_id
  app_instance_profile   = module.iam.app_instance_profile_name
  tools_instance_profile = module.iam.tools_instance_profile_name
  db_instance_profile    = module.iam.db_instance_profile_name
  alb_target_group_arn   = module.alb.target_group_arn
  app_instance_type      = var.app_instance_type
  db_instance_type       = var.db_instance_type
  tools_instance_type    = var.tools_instance_type
}

# ─── Monitoring ──────────────────────────────────────────────────────────────
module "monitoring" {
  source = "../../modules/monitoring"

  project_name      = var.project_name
  environment       = var.environment
  aws_region        = var.aws_region
  slack_webhook_url = var.slack_webhook_url
  alb_arn_suffix    = module.alb.alb_arn_suffix
  app_instance_ids  = module.compute.app_instance_ids
  db_instance_id    = module.compute.db_instance_id
  sns_email         = var.sns_email
}
