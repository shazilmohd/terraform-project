# Stage Environment - Terraform Variables
# This file should be added to .gitignore or use environment variables instead
# For git-safe approach, use: terraform -var-file="terraform.tfvars" or export TF_VAR_* env vars

aws_region  = "ap-south-1"
environment = "stage"

# VPC Configuration
vpc_cidr             = "10.1.0.0/16"
public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
private_subnet_cidrs = ["10.1.3.0/24", "10.1.4.0/24"]

# EC2 Configuration - Free Tier eligible (t3.micro is newer generation)
instance_type    = "t3.micro"
instance_count   = 2
root_volume_size = 20

# Secrets Manager Configuration
secrets_manager_secret_name = "terraform-env-vars"

# Key pair name (from AWS EC2 Key Pairs) - leave empty to skip key setup
# key_pair_name = "my-stage-keypair"
