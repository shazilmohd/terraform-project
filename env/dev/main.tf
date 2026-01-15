# Dev Environment - Variables
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

# EC2 Module
module "web_server" {
  source = "../../modules/compute/ec2"

  instance_type       = var.instance_type
  ami_id              = data.aws_ami.ubuntu.id
  subnet_ids          = module.vpc.public_subnet_ids
  security_group_ids  = [module.web_security_group.security_group_id]
  instance_count      = var.instance_count
  associate_public_ip = true
  key_name            = var.key_pair_name != "" ? var.key_pair_name : null
  user_data           = file("${path.module}/../../scripts/install_apache2.sh")
  root_volume_size    = var.root_volume_size

  tags = {
    Environment = var.environment
    Name        = "${var.environment}-web-server"
  }
}

# Secrets Manager Module
module "app_secrets" {
  source = "../../modules/secrets/secret_manager"

  secret_name = "${var.environment}-app-secrets"
  description = "Application secrets for ${var.environment} environment"

  tags = {
    Environment = var.environment
    Name        = "${var.environment}-app-secrets"
  }
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
