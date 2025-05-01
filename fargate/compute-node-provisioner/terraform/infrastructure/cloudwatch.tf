resource "aws_cloudwatch_dashboard" "s3_endpoint_dashboard" {
  dashboard_name = "s3-vpc-endpoint-metrics"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/PrivateLinkEndpoints", "BytesProcessed", "VpcEndpointId", aws_vpc_endpoint.s3.id, "ServiceName", "com.amazonaws.${var.region}.s3"]
          ]
          period  = 3600
          stat    = "Sum"
          region  = var.region
          title   = "S3 Endpoint - Bytes Processed"
        }
      }
    ]
  })
}