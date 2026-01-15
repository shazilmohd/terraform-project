resource "aws_secretsmanager_secret" "main" {
  name                    = var.secret_name
  description             = var.description
  recovery_window_in_days = var.recovery_window_in_days

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "main" {
  count         = var.secret_string != "" || var.secret_binary != "" ? 1 : 0
  secret_id     = aws_secretsmanager_secret.main.id
  secret_string = var.secret_string != "" ? var.secret_string : null
  secret_binary = var.secret_binary != "" ? var.secret_binary : null
}
