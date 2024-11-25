// Creates Secrets Manager resource
resource "aws_secretsmanager_secret" "api_key_secret" {
  name = "api-key-secret-${var.account_id}-${var.env}-${var.tag}"
  recovery_window_in_days = 0
}