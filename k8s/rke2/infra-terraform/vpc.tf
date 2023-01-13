resource "aws_vpc" "rke2_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = {
    Name = "${var.environment}-vpc"
  }
}

resource "aws_vpc_dhcp_options" "dns_resolver" {
  domain_name_servers = var.dhcp_servers
  domain_name         = var.dhcp_options_domain_name
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_dhcp_options_association" "dns_resolver" {
  vpc_id          = aws_vpc.rke2_vpc.id
  dhcp_options_id = aws_vpc_dhcp_options.dns_resolver.id
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_internet_gateway" "rke2" {
  vpc_id = aws_vpc.rke2_vpc.id
  tags   = {
    Name = "${var.environment}-vpc-igw"
  }
}

resource "aws_eip" "rke2" {
  vpc  = true
  tags = {
    Name = "${var.environment}-vpc-ngw-eip"
  }
}

resource "aws_nat_gateway" "rke2" {
  subnet_id     = aws_subnet.rke2_public.id
  allocation_id = aws_eip.rke2.id
  tags          = {
    Name = "${var.environment}-vpc-ngw"
  }
}

resource "aws_subnet" "rke2_public" {
  vpc_id     = aws_vpc.rke2_vpc.id
  cidr_block = var.public_cidr
  tags       = {
    Name = "${var.environment}-vpc-rke2-public-subnet"
  }
}

resource "aws_subnet" "rke2_private" {
  vpc_id     = aws_vpc.rke2_vpc.id
  cidr_block = var.private_cidr
  tags       = {
    Name = "${var.environment}-vpc-rke2-private-subnet"
  }
}

resource "aws_route_table" "rke2_public" {
  vpc_id = aws_vpc.rke2_vpc.id
  tags   = {
    Name = "${var.environment}-vpc-rke2-public-rt"
  }
}

resource "aws_route" "igw" {
  route_table_id         = aws_route_table.rke2_public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.rke2.id
}

resource "aws_route_table_association" "private_to_private" {
  route_table_id = aws_default_route_table.rke2_private.id
  subnet_id      = aws_subnet.rke2_private.id
}

resource "aws_default_route_table" "rke2_private" {
  default_route_table_id = aws_vpc.rke2_vpc.default_route_table_id
  tags                   = {
    Name = "${var.environment}-vpc-rke2-private-rt"
  }
}

resource "aws_route" "ngw" {
  route_table_id         = aws_default_route_table.rke2_private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.rke2.id
  depends_on             = [
    aws_default_route_table.rke2_private,
    aws_nat_gateway.rke2,
  ]
}

resource "aws_route_table_association" "public_to_public" {
  route_table_id = aws_route_table.rke2_public.id
  subnet_id      = aws_subnet.rke2_public.id
}