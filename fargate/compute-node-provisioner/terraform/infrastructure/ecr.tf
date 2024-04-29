resource "aws_ecr_repository" "workflow-manager" {
  name                 = "workflow-manager-${var.account_id}-${var.env}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }
}