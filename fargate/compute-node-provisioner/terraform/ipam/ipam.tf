# 1. Create an IPAM
resource "aws_vpc_ipam" "compute_nodes" {
  operating_regions {
    region_name = var.region
  }

  description = "Compute nodes IPAM"
}

# 2. Create an IPAM Pool
resource "aws_vpc_ipam_pool" "compute_nodes" {
  address_family = "ipv4"
  ipam_scope_id  = aws_vpc_ipam.compute_nodes.private_default_scope_id
  locale         = var.region
  description    = "Compute nodes IPAM Pool"

  provisioned_cidr {
    cidr = "10.0.0.0/16"
  }
}