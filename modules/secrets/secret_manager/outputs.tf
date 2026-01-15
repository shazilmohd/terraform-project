output "secret_id" {
  description = "The ID of the secret"
  value       = try(aws_secretsmanager_secret.main[0].id, null)
}

output "secret_arn" {
  description = "The ARN of the secret"
  value       = try(aws_secretsmanager_secret.main[0].arn, null)
}

output "secret_version_id" {
  description = "The version ID of the secret"
  value       = try(aws_secretsmanager_secret_version.main[0].version_id, null)
}
