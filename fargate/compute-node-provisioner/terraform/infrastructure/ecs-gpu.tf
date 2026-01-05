// ----------------------------------------------------------------------------
// GPU Cluster Capacity Providers
// Adds GPU capacity to the existing workflow cluster
// ----------------------------------------------------------------------------

resource "aws_ecs_cluster_capacity_providers" "workflow_cluster" {
  cluster_name = aws_ecs_cluster.workflow_cluster.name

  capacity_providers = [
    "FARGATE",
    aws_ecs_capacity_provider.gpu_managed_instances.name,
  ]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

// ----------------------------------------------------------------------------
// GPU EC2 Capacity Provider
// ----------------------------------------------------------------------------

resource "aws_ecs_capacity_provider" "gpu_managed_instances" {
  name = "gpu-cp-${var.account_id}-${var.env}-${var.node_identifier}"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.gpu_instances.arn
    managed_termination_protection = "DISABLED"

    managed_scaling {
      status                    = "ENABLED"
      target_capacity           = 100
      minimum_scaling_step_size = 1
      maximum_scaling_step_size = 1
    }
  }
}

// ----------------------------------------------------------------------------
// GPU Auto Scaling Group
// ----------------------------------------------------------------------------

resource "aws_autoscaling_group" "gpu_instances" {
  name                = "gpu-asg-${var.account_id}-${var.env}-${var.node_identifier}"
  vpc_zone_identifier = local.subnet_ids_list
  min_size            = 0
  max_size            = 2
  desired_capacity    = 0

  mixed_instances_policy {
    instances_distribution {
      on_demand_percentage_above_base_capacity = 100
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.gpu_instances.id
        version            = "$Latest"
      }

      override {
        instance_type = "g4dn.2xlarge"  # 32 GB, 1 GPU
      }
      override {
        instance_type = "g4dn.4xlarge"  # 64 GB, 1 GPU
      }
      override {
        instance_type = "g4dn.8xlarge"  # 128 GB, 1 GPU
      }
    }
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = "true"
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "gpu-ecs-${var.account_id}-${var.env}-${var.node_identifier}"
    propagate_at_launch = true
  }
}

// ----------------------------------------------------------------------------
// GPU Launch Template
// ----------------------------------------------------------------------------

resource "aws_launch_template" "gpu_instances" {
  name_prefix   = "gpu-ecs-${var.account_id}-${var.env}-${var.node_identifier}-"
  image_id      = data.aws_ssm_parameter.ecs_gpu_ami.value
  instance_type = "g4dn.2xlarge"

  iam_instance_profile {
    name = aws_iam_instance_profile.gpu_ecs_instance.name
  }

  vpc_security_group_ids = [aws_default_security_group.default.id]

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 100
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.workflow_cluster.name} >> /etc/ecs/ecs.config
    echo ECS_ENABLE_GPU_SUPPORT=true >> /etc/ecs/ecs.config
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "gpu-ecs-${var.account_id}-${var.env}-${var.node_identifier}"
    }
  }
}

// ----------------------------------------------------------------------------
// ECS GPU-optimized AMI
// ----------------------------------------------------------------------------

data "aws_ssm_parameter" "ecs_gpu_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/gpu/recommended/image_id"
}

// ----------------------------------------------------------------------------
// IAM Role for GPU EC2 Instances
// ----------------------------------------------------------------------------

resource "aws_iam_role" "gpu_ecs_instance_role" {
  name = "gpu-ecs-instance-role-${var.account_id}-${var.env}-${var.node_identifier}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "gpu_ecs_instance_role_policy" {
  role       = aws_iam_role.gpu_ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "gpu_ecs_instance_ssm_policy" {
  role       = aws_iam_role.gpu_ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "gpu_ecs_instance" {
  name = "gpu-ecs-instance-profile-${var.account_id}-${var.env}-${var.node_identifier}"
  role = aws_iam_role.gpu_ecs_instance_role.name
}
