// creates an archive and uploads to s3 bucket
data "archive_file" "compute_gateway_lambda" {
  type = "zip"

  source_dir  = "${path.module}/compute-gateway-lambda"
  output_path = "${path.module}/compute-gateway-lambda.zip"
}

// provides an s3 object resource
resource "aws_s3_object" "compute_gateway_lambda" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "compute-gateway-lambda-${var.account_id}-${var.env}.zip"
  source = data.archive_file.compute_gateway_lambda.output_path

  etag = filemd5(data.archive_file.compute_gateway_lambda.output_path)
}

// policy document - compute gateway lambda
data "aws_iam_policy_document" "iam_policy_document_gateway" {
  statement {
    sid    = "CloudwatchPermissions"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:GetLogEvents"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "SQSPermissions"
    effect = "Allow"
    actions = [
      "sqs:sendmessage",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "SecretsManager"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      "*"
    ]
  }

    statement {
    sid    = "S3Permissions"
    effect = "Allow"
    actions = [
      "s3:*",
    ]
    resources = ["*"]
  }
}