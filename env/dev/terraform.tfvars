# Dev Environment - Terraform Variables
# This file should be added to .gitignore or use environment variables instead
# For git-safe approach, use: terraform -var-file="terraform.tfvars" or export TF_VAR_* env vars

aws_region  = "ap-south-1"
environment = "dev"

# VPC Configuration
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24"]
private_subnet_cidrs = ["10.0.2.0/24"]

# EC2 Configuration - Free Tier eligible
instance_type    = "t2.micro"
instance_count   = 1
root_volume_size = 20

# Secrets Manager Configuration
secrets_manager_secret_name = "dev/terraform-env-vars"

# Key pair name (from AWS EC2 Key Pairs) - leave empty to skip key setup
# key_pair_name = "my-dev-keypair"
