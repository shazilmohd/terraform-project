resource "aws_secretsmanager_secret" "main" {
  count                   = var.create_secret ? 1 : 0
  name                    = var.secret_name
  description             = var.description
  recovery_window_in_days = var.recovery_window_in_days

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "main" {
  count         = var.create_secret && (var.secret_string != "" || var.secret_binary != "") ? 1 : 0
  secret_id     = aws_secretsmanager_secret.main[0].id
  secret_string = var.secret_string != "" ? var.secret_string : null
  secret_binary = var.secret_binary != "" ? var.secret_binary : null
}
