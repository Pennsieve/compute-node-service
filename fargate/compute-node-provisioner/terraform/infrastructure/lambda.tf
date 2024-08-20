// Compute Gateway Lambda
resource "aws_lambda_function" "compute_gateway" {
  function_name = "compute-gateway-${var.account_id}-${var.env}"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "lambda_function.lambda_handler"
  description   = "Compute Node Gateway"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.compute_gateway_lambda.key

  source_code_hash = data.archive_file.compute_gateway_lambda.output_base64sha256

  runtime = "python3.12"
  timeout = 60

  environment {
    variables = {
      REGION = var.region
      SQS_URL = aws_sqs_queue.workflow_queue.id
      API_KEY_SM_NAME = aws_secretsmanager_secret.api_key_secret.name
      ENV = var.env
    }
  }
}

resource "aws_cloudwatch_log_group" "compute_gateway-lambda" {
  name = "/aws/lambda/${aws_lambda_function.compute_gateway.function_name}"

  retention_in_days = 30
}

resource "aws_lambda_function_url" "compute_gateway" {
  function_name      = aws_lambda_function.compute_gateway.function_name
  authorization_type = "NONE"
}