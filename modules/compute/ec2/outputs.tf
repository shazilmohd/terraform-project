output "instance_ids" {
  description = "List of EC2 instance IDs"
  value       = aws_instance.main[*].id
}

output "instance_private_ips" {
  description = "List of private IP addresses"
  value       = aws_instance.main[*].private_ip
}

output "instance_public_ips" {
  description = "List of public IP addresses (if assigned)"
  value       = aws_instance.main[*].public_ip
}

output "instance_arns" {
  description = "List of instance ARNs"
  value       = aws_instance.main[*].arn
}
