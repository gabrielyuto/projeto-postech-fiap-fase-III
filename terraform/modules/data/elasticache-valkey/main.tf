# Agrupa as subnets onde o cache pode rodar.
resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.name}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = { Name = "${var.name}-subnet-group" }
}

# Só aceita conexões na porta do Valkey (6379) vindas dos CIDRs informados.
resource "aws_security_group" "cache" {
  name   = "${var.name}-sg"
  vpc_id = var.vpc_id

  ingress {
    description = "Valkey"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  tags = { Name = "${var.name}-sg" }
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id = var.name
  description          = "Cache Valkey ${var.name}"

  engine         = "valkey"
  engine_version = var.engine_version
  node_type      = var.node_type
  port           = 6379

  num_cache_clusters = var.num_cache_clusters

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = [aws_security_group.cache.id]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true # os clientes precisam conectar com TLS
}