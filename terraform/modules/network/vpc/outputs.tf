output "vpc_id" {
  value = aws_vpc.this.id
}

output "vpc_cidr" {
  value = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  value = [for k, v in var.subnets : aws_subnet.this[k].id if v.tier == "public"]
}

output "eks_subnet_ids" {
  value = [for k, v in var.subnets : aws_subnet.this[k].id if v.tier == "eks"]
}

output "db_subnet_ids" {
  value = [for k, v in var.subnets : aws_subnet.this[k].id if v.tier == "db"]
}