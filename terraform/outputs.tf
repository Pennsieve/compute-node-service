output "service_lambda_arn" {
  value = aws_lambda_function.service_lambda.arn
}

output "service_lambda_invoke_arn" {
  value = aws_lambda_function.service_lambda.invoke_arn
}

output "service_lambda_function_name" {
  value = aws_lambda_function.service_lambda.function_name
}

output "compute_nodes_table_name" {
  value = aws_dynamodb_table.compute_nodes_table.name
}

output "compute_nodes_table_arn" {
  value = aws_dynamodb_table.compute_nodes_table.arn
}

output "task_definition_arn" {
  value = aws_ecs_task_definition.provisioner_ecs_task_definition.arn
  description = "ARN of the ECS task definition for compute node provisioner"
}

# ECS Cluster ARN
output "ecs_cluster_arn" {
  value = data.terraform_remote_state.fargate.outputs.ecs_cluster_arn
  description = "ARN of the ECS cluster for running compute node tasks"
}

# Fargate Security Group ID
output "fargate_security_group_id" {
  value = data.terraform_remote_state.platform_infrastructure.outputs.rehydration_fargate_security_group_id
  description = "Security group ID for Fargate tasks"
}

# Task Container Name
output "task_container_name" {
  value = var.tier  # or whatever variable holds the container name
  description = "Name of the container in the task definition"
}