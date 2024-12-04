// Creates Secrets Manager resource
resource "aws_secretsmanager_secret" "api_key_secret" {
  name = "api-key-secret-${var.account_id}-${var.env}-${var.node_identifier}"
  recovery_window_in_days = 0
}