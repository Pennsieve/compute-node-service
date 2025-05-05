# resource "aws_cloudwatch_dashboard" "s3_endpoint_dashboard_simple" {
#   dashboard_name = "s3-vpc-endpoint-basic"
  
#   dashboard_body = jsonencode({
#     widgets = [
#       {
#         type   = "metric"
#         x      = 0
#         y      = 0
#         width  = 12
#         height = 6
#         properties = {
#           metrics = [
#             ["AWS/S3", "AllRequests", "FilterId", aws_vpc_endpoint.s3.id]
#           ]
#           period  = 3600
#           stat    = "Sum"
#           region  = var.region
#           title   = "S3 Gateway Endpoint - All Requests"
#         }
#       }
#     ]
#   })
# }