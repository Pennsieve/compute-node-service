resource "aws_ecr_repository" "workflow-manager" {
  name                 = "workflow-manager-${var.account_id}-${var.env}-${var.tag}"
  image_tag_mutability = "MUTABLE"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = false
  }
}