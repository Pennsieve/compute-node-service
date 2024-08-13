// Lambda gateway function
// allow lambda to access resources in your AWS account
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda-${var.account_id}-${var.env}"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

//  gateway lambda policy
resource "aws_iam_role_policy_attachment" "gateway_lambda_policy" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_iam_policy.arn
}

resource "aws_iam_policy" "lambda_iam_policy" {
  name   = "lambda-iam-policy-${var.account_id}-${var.env}"
  path   = "/"
  policy = data.aws_iam_policy_document.iam_policy_document_gateway.json
}

// Workflow manager
// ECS task IAM role
resource "aws_iam_role" "task_role_for_ecs_task" {
  name               = "task_role_for_ecs_task-${var.account_id}-${var.env}"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_role_assume_role.json
  managed_policy_arns = [aws_iam_policy.efs_policy.arn,aws_iam_policy.ecs_run_task.arn,aws_iam_policy.ecs_get_secrets.arn,aws_iam_policy.s3_policy.arn]
}

resource "aws_iam_policy" "efs_policy" {
  name = "ecs_task_role_efs_policy-${var.account_id}-${var.env}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
          "elasticfilesystem:ClientRootAccess"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_policy" "s3_policy" {
  name = "ecs_task_role_s3_policy-${var.account_id}-${var.env}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:*"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_policy" "ecs_run_task" {
  name = "ecs_task_role_run_task-${var.account_id}-${var.env}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecs:DescribeTasks",
          "ecs:RunTask",
          "ecs:ListTasks",
          "iam:PassRole",
          "sqs:receivemessage",
          "sqs:deletemessage",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_policy" "ecs_get_secrets" {
  name = "ecs_task_role_ecs_get_secrets-${var.account_id}-${var.env}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

data "aws_iam_policy_document" "ecs_task_role_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

// ECS Task Execution IAM role
resource "aws_iam_role" "execution_role_for_ecs_task" {
  name               = "execution_role_for_ecs_task-${var.account_id}-${var.env}"
  assume_role_policy = data.aws_iam_policy_document.ecs_execution_role_assume_role.json
  managed_policy_arns = [aws_iam_policy.ecs_execution_role_policy.arn]
}

resource "aws_iam_policy" "ecs_execution_role_policy" {
  name = "ecs_task_execution_role_policy-${var.account_id}-${var.env}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogGroup"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

data "aws_iam_policy_document" "ecs_execution_role_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}