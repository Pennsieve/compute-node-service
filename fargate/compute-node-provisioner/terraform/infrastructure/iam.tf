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