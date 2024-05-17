output "compute_gateway_url" {
  description = "Compute Gateway Public URL"

  value = aws_lambda_function_url.compute_gateway.function_url
}

output "workflow_manager_ecr_repository" {
  description = "Workflow Manager ECR repository"

  value = aws_ecr_repository.workflow-manager.repository_url
}

output "queue_url" {
  description = "Queue URL"

  value = aws_sqs_queue.workflow_queue.id
}

output "efs_id" {
  description = "EFS ID"

  value = aws_efs_file_system.workflow.id
}