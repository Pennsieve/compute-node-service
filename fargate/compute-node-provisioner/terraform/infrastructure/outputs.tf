output "compute_gateway_url" {
  description = "Compute Gateway Public URL"

  value = aws_lambda_function_url.compute_gateway.function_url
}

output "queue_url" {
  description = "Queue URL"

  value = aws_sqs_queue.workflow_queue.id
}

output "efs_id" {
  description = "EFS ID"

  value = aws_efs_file_system.workflow.id
}

output "visualization_service_url" {
  description = "Visualization Service URL"

  value = aws_lb.viz-lb.dns_name
}