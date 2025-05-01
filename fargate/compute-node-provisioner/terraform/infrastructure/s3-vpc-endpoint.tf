# data "aws_iam_policy_document" "s3_endpoint_policy" {
#   statement {
#     effect    = "Allow"
#     actions   = ["s3:*"]
#     resources = ["*"]
    
#     principals {
#       type        = "*"
#       identifiers = ["*"]
#     }
#   }
# }

# Retrieve all route tables associated with the default VPC
data "aws_route_tables" "default_vpc_route_tables" {
  vpc_id = aws_default_vpc.default.id
}

# adds S3 VPC endpoint
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_default_vpc.default.id
  service_name = "com.amazonaws.${var.region}.s3"
  route_table_ids   = data.aws_route_tables.default_vpc_route_tables.ids

  tags = {
    Environment = "${var.env}"
    Region = "${var.region}"
    Name = "${var.region} S3 VPC endpoint"
  }
}