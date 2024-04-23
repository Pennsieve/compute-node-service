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
  name               = "iam_for_lambda-${var.account_id}"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

// attach policy to allow gateway lambda to start an ECS task and to write to Cloudwatch
resource "aws_iam_role_policy_attachment" "lambda_policy_ecs" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_iam_policy.arn
}

resource "aws_iam_policy" "lambda_iam_policy" {
  name   = "lambda-iam-policy-${var.account_id}"
  path   = "/"
  policy = data.aws_iam_policy_document.iam_policy_document_gateway.json
}