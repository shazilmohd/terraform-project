# Prod Environment - Outputs

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "web_security_group_id" {
  description = "Web security group ID"
  value       = module.web_security_group.security_group_id
}

output "web_server_instance_ids" {
  description = "Web server instance IDs"
  value       = module.web_server.instance_ids
}

output "web_server_public_ips" {
  description = "Web server public IP addresses"
  value       = module.web_server.instance_public_ips
}

output "web_server_private_ips" {
  description = "Web server private IP addresses"
  value       = module.web_server.instance_private_ips
}

output "app_secrets_id" {
  description = "Application secrets ID"
  value       = module.app_secrets.secret_id
}

output "app_secrets_arn" {
  description = "Application secrets ARN"
  value       = module.app_secrets.secret_arn
}

output "ec2_instance_role_arn" {
  description = "EC2 instance role ARN"
  value       = module.ec2_instance_role.instance_role_arn
}

output "environment_name" {
  description = "Environment name"
  value       = var.environment
}
