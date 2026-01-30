data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  az_count = max(var.public_subnet_count, var.private_subnet_count)
  azs      = slice(data.aws_availability_zones.available.names, 0, local.az_count)

  public_subnet_cidrs = [
    for i in range(var.public_subnet_count) :
    cidrsubnet(var.cidr_block, var.subnet_newbits, i)
  ]

  private_subnet_cidrs = [
    for i in range(var.private_subnet_count) :
    cidrsubnet(var.cidr_block, var.subnet_newbits, i + var.public_subnet_count)
  ]

  nat_gateway_count        = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : var.public_subnet_count) : 0
  nat_gateway_subnet_index = var.single_nat_gateway ? [0] : [for i in range(var.public_subnet_count) : i]

  common_tags = merge(
    var.tags,
    {
      app         = var.app_name
      component   = "network"
      environment = var.environment
      managedby   = "terraform"
      owner       = var.owner
      project     = var.project
    }
  )
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames
  tags                 = merge(local.common_tags, { Name = "${var.app_name}-${var.environment}-vpc" })

  lifecycle {
    precondition {
      condition     = length(data.aws_availability_zones.available.names) >= local.az_count
      error_message = "Not enough availability zones in this region for the requested subnet counts."
    }
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = local.common_tags
}

resource "aws_subnet" "public" {
  for_each                = { for i in range(var.public_subnet_count) : i => i }
  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_subnet_cidrs[each.key]
  availability_zone       = local.azs[each.key]
  map_public_ip_on_launch = var.public_subnet_map_public_ip_on_launch
  tags                    = merge(local.common_tags, { tier = "public" })
}

resource "aws_subnet" "private" {
  for_each          = { for i in range(var.private_subnet_count) : i => i }
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.private_subnet_cidrs[each.key]
  availability_zone = local.azs[each.key]
  tags              = merge(local.common_tags, { tier = "private" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.common_tags, { tier = "public" })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  count  = local.nat_gateway_count
  domain = "vpc"
  tags   = merge(local.common_tags, { tier = "nat" })
}

resource "aws_nat_gateway" "this" {
  count         = local.nat_gateway_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[local.nat_gateway_subnet_index[count.index]].id
  tags          = merge(local.common_tags, { tier = "nat" })
}

resource "aws_route_table" "private" {
  for_each = aws_subnet.private
  vpc_id   = aws_vpc.this.id
  tags     = merge(local.common_tags, { tier = "private" })
}

resource "aws_route" "private_nat" {
  for_each               = var.enable_nat_gateway ? aws_route_table.private : {}
  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.this[
    var.single_nat_gateway ? 0 : tonumber(each.key) % local.nat_gateway_count
  ].id
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id
  tags   = local.common_tags

  ingress = []
  egress  = []
}
