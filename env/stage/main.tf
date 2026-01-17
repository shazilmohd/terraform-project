# Stage Environment - Main Configuration
# All actual values should be fetched from AWS Secrets Manager or environment variables

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data source to fetch secrets from AWS Secrets Manager
data "aws_secretsmanager_secret_version" "env_secrets" {
  secret_id = var.secrets_manager_secret_name
}

locals {
  secrets = jsondecode(data.aws_secretsmanager_secret_version.env_secrets.secret_string)
  
  # Consume secrets for EC2 configuration
  # Expected structure in Secrets Manager:
  # {
  #   "app_name": "my-app",
  #   "app_version": "1.0.0",
  #   "contact_email": "ops@company.com"
  # }
  app_name        = lookup(local.secrets, "app_name", "${var.environment}-app")
  app_version     = lookup(local.secrets, "app_version", "1.0.0")
  contact_email   = lookup(local.secrets, "contact_email", "ops@company.com")
}

# Data source to get latest Ubuntu LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# VPC Module
module "vpc" {
  source = "../../modules/networking/vpc"

  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs

  tags = {
    Environment = var.environment
    Name        = "${var.environment}-vpc"
  }
}

# Security Group Module
module "web_security_group" {
  source = "../../modules/networking/security_group"

  vpc_id              = module.vpc.vpc_id
  security_group_name = "${var.environment}-web-sg"

  ingress_rules = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"] # Consider restricting in production
      description = "SSH access"
    },
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTP access"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTPS access"
    }
  ]

  tags = {
    Environment = var.environment
    Name        = "${var.environment}-web-sg"
  }
}

# IAM Instance Role Module
module "ec2_instance_role" {
  source = "../../modules/iam/instance_role"

  environment = var.environment
  
  tags = {
    Environment = var.environment
    Name        = "${var.environment}-ec2-role"
  }
}

# EC2 Module
module "web_server" {
  source = "../../modules/compute/ec2"

  instance_type        = var.instance_type
  ami_id               = data.aws_ami.ubuntu.id
  subnet_ids           = module.vpc.public_subnet_ids
  security_group_ids   = [module.web_security_group.security_group_id]
  instance_count       = var.instance_count
  associate_public_ip  = true
  key_name             = var.key_pair_name != "" ? var.key_pair_name : null
  iam_instance_profile = module.ec2_instance_role.instance_profile_name
  user_data            = base64encode(templatefile("${path.module}/../../scripts/install_apache2.sh", { environment = var.environment }))
  root_volume_size     = var.root_volume_size

  tags = {
    Environment    = var.environment
    Name           = "${var.environment}-web-server"
    AppName        = local.app_name
    AppVersion     = local.app_version
    ManagedBy      = "Terraform"
    ContactEmail   = local.contact_email
  }

  depends_on = [module.ec2_instance_role]
}

# Secrets Manager Module
module "app_secrets" {
  source = "../../modules/secrets/secret_manager"

  create_secret = false
  secret_name = "${var.environment}-app-secrets-v1"
  description = "Application secrets for ${var.environment} environment"
  recovery_window_in_days = 0

  tags = {
    Environment = var.environment
    Name        = "${var.environment}-app-secrets-v1"
  }
}
