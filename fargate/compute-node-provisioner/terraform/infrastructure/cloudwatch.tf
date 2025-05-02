resource "aws_cloudwatch_dashboard" "s3_gateway_endpoint_dashboard" {
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
            ["AWS/S3", "AllRequests", "FilterId", "vpce-${aws_vpc_endpoint.s3.id}"],
            ["AWS/S3", "GetRequests", "FilterId", "vpce-${aws_vpc_endpoint.s3.id}"],
            ["AWS/S3", "PutRequests", "FilterId", "vpce-${aws_vpc_endpoint.s3.id}"]
          ]
          period  = 3600
          stat    = "Sum"
          region  = var.region
          title   = "S3 Gateway Endpoint - Requests"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/S3", "BytesDownloaded", "FilterId", "vpce-${aws_vpc_endpoint.s3.id}"],
            ["AWS/S3", "BytesUploaded", "FilterId", "vpce-${aws_vpc_endpoint.s3.id}"]
          ]
          period  = 3600
          stat    = "Sum"
          region  = var.region
          title   = "S3 Gateway Endpoint - Data Transfer"
        }
      }
    ]
  })
}