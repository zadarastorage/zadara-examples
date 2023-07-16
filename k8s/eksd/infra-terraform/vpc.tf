resource "aws_vpc" "eksd_vpc" {
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
  vpc_id          = aws_vpc.eksd_vpc.id
  dhcp_options_id = aws_vpc_dhcp_options.dns_resolver.id
  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_vpc.eksd_vpc]
}

resource "aws_internet_gateway" "eksd" {
  vpc_id = aws_vpc.eksd_vpc.id
  tags   = {
    Name = "${var.environment}-vpc-igw"
  }

  depends_on = [aws_vpc.eksd_vpc]
}

resource "aws_eip" "eksd" {
  vpc  = true
  tags = {
    Name = "${var.environment}-vpc-ngw-eip"
  }

  depends_on = [aws_vpc.eksd_vpc, aws_route_table.eksd_public]
}

resource "aws_nat_gateway" "eksd" {
  subnet_id     = aws_subnet.eksd_public.id
  allocation_id = aws_eip.eksd.id
  tags          = {
    Name = "${var.environment}-vpc-ngw"
  }

  depends_on = [aws_route.igw, aws_route_table_association.public_to_public]
}

resource "aws_subnet" "eksd_public" {
  vpc_id     = aws_vpc.eksd_vpc.id
  cidr_block = var.public_cidr
  tags       = {
    Name = "${var.environment}-vpc-eksd-public-subnet"
  }

  depends_on = [aws_vpc.eksd_vpc]
}

resource "aws_subnet" "eksd_private" {
  vpc_id     = aws_vpc.eksd_vpc.id
  cidr_block = var.private_cidr
  tags       = {
    Name = "${var.environment}-vpc-eksd-private-subnet"
  }

  depends_on = [aws_vpc.eksd_vpc]
}

resource "aws_route_table" "eksd_public" {
  vpc_id = aws_vpc.eksd_vpc.id
  tags   = {
    Name = "${var.environment}-vpc-eksd-public-rt"
  }

  depends_on = [aws_vpc.eksd_vpc]
}

resource "aws_route" "igw" {
  route_table_id         = aws_route_table.eksd_public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.eksd.id
}

resource "aws_route_table_association" "private_to_private" {
  route_table_id = aws_default_route_table.eksd_private.id
  subnet_id      = aws_subnet.eksd_private.id
}

resource "aws_default_route_table" "eksd_private" {
  default_route_table_id = aws_vpc.eksd_vpc.default_route_table_id
  tags                   = {
    Name = "${var.environment}-vpc-eksd-private-rt"
  }
}

resource "aws_route" "ngw" {
  route_table_id         = aws_default_route_table.eksd_private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.eksd.id
  depends_on             = [
    aws_vpc.eksd_vpc,
    aws_default_route_table.eksd_private,
    aws_nat_gateway.eksd,
  ]
}

resource "aws_route_table_association" "public_to_public" {
  route_table_id = aws_route_table.eksd_public.id
  subnet_id      = aws_subnet.eksd_public.id
}
