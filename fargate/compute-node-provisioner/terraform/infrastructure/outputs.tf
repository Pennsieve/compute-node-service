output "compute_gateway_url" {
  description = "Compute Gateway Public URL"

  value = aws_lambda_function_url.compute_gateway.function_url
}