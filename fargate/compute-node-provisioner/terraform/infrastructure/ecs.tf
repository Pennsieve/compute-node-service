// ECS Cluster
resource "aws_kms_key" "ecs_cluster" {
  description             = "ecs_cluster_kms_key"
  deletion_window_in_days = 7
}

resource "aws_cloudwatch_log_group" "ecs_cluster" {
  name = "ecs-cluster-log-${var.account_id}-${var.env}-${var.node_identifier}"
}

resource "aws_ecs_cluster" "workflow_cluster" {
  name = "workflow-cluster-${var.account_id}-${var.env}-${var.node_identifier}"

  configuration {
    execute_command_configuration {
      kms_key_id = aws_kms_key.ecs_cluster.arn
      logging    = "OVERRIDE"

      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.ecs_cluster.name
      }
    }
  }
}

// ECS Task definition - workflow manager
resource "aws_ecs_task_definition" "workflow-manager" {
  family                = "wm-${var.account_id}-${var.env}-${var.node_identifier}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.wm_cpu
  memory                   = var.wm_memory
  task_role_arn      = aws_iam_role.task_role_for_ecs_task.arn
  execution_role_arn = aws_iam_role.execution_role_for_ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "wm-${var.account_id}-${var.env}-${var.node_identifier}"
      image     = "${var.workflow_manager_image_url}:${var.workflow_manager_image_tag}"
      environment: [
      { name: "SQS_URL", value: aws_sqs_queue.workflow_queue.id},
      { name: "SUBNET_IDS", value: local.subnet_ids},
      { name: "CLUSTER_NAME", value: aws_ecs_cluster.workflow_cluster.name},
      { name: "SECURITY_GROUP_ID", value: aws_default_security_group.default.id},
      { name: "VIZ_SECURITY_GROUP_ID", value: aws_security_group.viz.id},
      { name: "VIZ_TASK_DEFINITION_NAME", value: aws_ecs_task_definition.visualization-service.arn},
      { name: "VIZ_CONTAINER_NAME", value: aws_ecs_task_definition.visualization-service.family},
      { name: "ENVIRONMENT", value: var.env},
      { name: "BASE_DIR", value: "/mnt/efs"},
      { name: "REGION", value: var.region},
      ],
      essential = true
      portMappings = [
        {
          containerPort = 8081
          hostPort      = 8081
        }
      ]
      mountPoints = [
        {
          sourceVolume = "wm-storage-${var.account_id}-${var.env}-${var.node_identifier}"
          containerPath = "/mnt/efs"
          readOnly = false
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group = "/ecs/wm/${var.account_id}-${var.env}-${var.node_identifier}"
          awslogs-region = var.region
          awslogs-stream-prefix = "ecs"
          awslogs-create-group = "true"
        }
      }
    }
  ])

  volume {
    name = "wm-storage-${var.account_id}-${var.env}-${var.node_identifier}"

    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.workflow.id
      root_directory          = "/"
    }
  }
}

resource "aws_ecs_service" "workflow-manager" {
  name            = "wm-${var.account_id}-${var.env}-${var.node_identifier}"
  cluster         = aws_ecs_cluster.workflow_cluster.id
  task_definition = aws_ecs_task_definition.workflow-manager.arn
  launch_type = "FARGATE"
  desired_count = 1

  network_configuration {
    subnets = local.subnet_ids_list
    assign_public_ip = true
    security_groups = [aws_default_security_group.default.id]
  }
}

// ECS Task definition - visualization service
resource "aws_ecs_task_definition" "visualization-service" {
  family                = "viz-${var.account_id}-${var.env}-${var.node_identifier}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.viz_cpu
  memory                   = var.viz_memory
  task_role_arn      = aws_iam_role.task_role_for_ecs_task.arn
  execution_role_arn = aws_iam_role.execution_role_for_ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "viz-${var.account_id}-${var.env}-${var.node_identifier}"
      image     = "${var.viz_image_url}:${var.viz_image_tag}"
      environment: [
      {name: "SQS_URL", value: aws_sqs_queue.workflow_queue.id},
      { name: "SUBNET_IDS", value: local.subnet_ids},
      { name: "CLUSTER_NAME", value: aws_ecs_cluster.workflow_cluster.name},
      { name: "DEFAULT_SECURITY_GROUP_ID", value: aws_default_security_group.default.id},
      { name: "ENVIRONMENT", value: var.env},
      { name: "BASE_DIR", value: "/mnt/efs"},
      { name: "REGION", value: var.region},
      { name: "TASK_DEFINITION_NAME", value: "viz-${var.account_id}-${var.env}-${var.node_identifier}"},
      { name: "CONTAINER_NAME", value: "viz-${var.account_id}-${var.env}-${var.node_identifier}"},
      ],
      essential = true
      portMappings = [
        {
          containerPort = 8050
          hostPort      = 8050
        }
      ]
      mountPoints = [
        {
          sourceVolume = "viz-storage-${var.account_id}-${var.env}-${var.node_identifier}"
          containerPath = "/mnt/efs"
          readOnly = false
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group = "/ecs/viz/${var.account_id}-${var.env}-${var.node_identifier}"
          awslogs-region = var.region
          awslogs-stream-prefix = "ecs"
          awslogs-create-group = "true"
        }
      }
    }
  ])

  volume {
    name = "viz-storage-${var.account_id}-${var.env}-${var.node_identifier}"

    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.workflow.id
      root_directory          = "/"
    }
  }
}

resource "aws_ecs_service" "visualization-service" {
  name            = "viz-${var.account_id}-${var.env}-${var.node_identifier}"
  cluster         = aws_ecs_cluster.workflow_cluster.id
  task_definition = aws_ecs_task_definition.visualization-service.arn
  launch_type = "FARGATE"
  desired_count = 0
  depends_on = [aws_lb_target_group.viz-target-group]

  network_configuration {
    subnets = local.subnet_ids_list
    assign_public_ip = true
    security_groups = [aws_default_security_group.default.id,aws_security_group.viz.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.viz-target-group.arn
    container_name   = "viz-${var.account_id}-${var.env}-${var.node_identifier}"
    container_port   = 8050
  }

  # lifecycle {
  #   ignore_changes = [desired_count]
  # }

}
