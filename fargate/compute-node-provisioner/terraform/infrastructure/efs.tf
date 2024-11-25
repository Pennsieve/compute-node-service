// EFS filesystem
resource "aws_efs_file_system" "workflow" {
  creation_token = "efs-${var.account_id}-${var.env}-${var.tag}"
  encrypted = true

  tags = {
    Name = "efs-${var.account_id}-${var.env}-${var.tag}"
  }
}

// mount target(s)
resource "aws_efs_mount_target" "mnt" {
  file_system_id = aws_efs_file_system.workflow.id
  subnet_id      = split(",", local.subnet_ids)[count.index]
  security_groups = [aws_default_security_group.default.id]
  count = 6
}