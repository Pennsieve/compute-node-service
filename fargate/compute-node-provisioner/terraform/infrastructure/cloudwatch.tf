data "aws_nat_gateways" "default_vpc_nat_gateways" {
  vpc_id = aws_default_vpc.default.id
  
  filter {
    name   = "state"
    values = ["available"]
  }
}

# Reference the first NAT Gateway (if any exist)
locals {
  nat_gateway_id = length(data.aws_nat_gateways.default_vpc_nat_gateways.ids) > 0 ? tolist(data.aws_nat_gateways.default_vpc_nat_gateways.ids)[0] : null
}

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
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/NATGateway", "BytesOutToDestination", "NatGatewayId", local.nat_gateway_id],
            ["AWS/NATGateway", "BytesProcessed", "NatGatewayId", local.nat_gateway_id]
          ]
          period  = 3600
          stat    = "Sum"
          region  = var.region
          title   = "NAT Gateway - Traffic"
        }
      }
    ]
  })
}