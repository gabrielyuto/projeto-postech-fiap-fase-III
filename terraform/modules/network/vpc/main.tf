locals {
  public_subnets = { for k, v in var.subnets : k => v if v.tier == "public" }
  eks_subnets    = { for k, v in var.subnets : k => v if v.tier == "eks" }
}

# VPC ----------------------------------------------------------------
resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true # necessário para o EKS e para o endpoint do RDS

  tags = { Name = var.name }
}

# Subnets ------------------------------------------------------------
resource "aws_subnet" "this" {
  for_each = var.subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = each.value.tier == "public" # se for publico true, se nao false

  tags = { Name = each.key }
}

# Internet Gateway ----------------------------------------------------
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = { Name = "${var.name}-igw" }
}

# NAT Gateway --------------------------------------------------------
# Fica em uma subnet pública (public-subnet-app-a) e usa um Elastic IP.
resource "aws_eip" "nat" {
  domain = "vpc" # só diz "este Elastic IP é para uso em uma VPC

  tags = { Name = "${var.name}-nat-eip" }
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.this["public-subnet-app-a"].id

  tags = { Name = "${var.name}-nat" }

  depends_on = [aws_internet_gateway.this]
}

# Route tables ------------------------------------------------------
resource "aws_route_table" "app_public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = { Name = "rtb-app-public" }
}

resource "aws_route_table" "eks_private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = { Name = "rtb-eks-private" }
}

resource "aws_route_table_association" "public" {
  for_each = local.public_subnets

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.app_public.id
}

resource "aws_route_table_association" "eks" {
  for_each = local.eks_subnets

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.eks_private.id
}

# As subnets de banco (tier = "db") não têm associação explícita: usam a
# route table principal da VPC, que só tem a rota local. Ficam sem saída
# para a internet.