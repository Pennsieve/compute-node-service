// SQS queue for pipeline runs
resource "aws_sqs_queue" "workflow_queue" {
  name                      = "queue-${var.account_id}-${var.env}"

  tags = {
    Environment = "${var.env}"
  }
}