# --- DB Subnet Group ---
# Recebe as subnets de banco (private-subnet-db-a e private-subnet-db-b).
resource "aws_db_subnet_group" "this" {
  name       = "${var.identifier}-subnet-group" # só um rótulo para o grupo
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.identifier}-subnet-group"
  })
}

# --- Security Group ---
# Só aceita PostgreSQL (5432) vindo dos CIDRs informados.
resource "aws_security_group" "rds" {
  name   = "${var.identifier}-sg"
  vpc_id = var.vpc_id

  ingress {
    description = "PostgreSQL"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  tags = merge(var.tags, {
    Name = "${var.identifier}-sg"
  })
}

# --- Instância RDS ---
resource "aws_db_instance" "this" {
  identifier     = var.identifier
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"

  db_name  = var.db_name
  username = var.db_username

  # A AWS gera a senha e a guarda no Secrets Manager (sem senha no código/state).
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Fixo: o banco fica só nas subnets privadas.
  publicly_accessible = false

  multi_az                = var.multi_az
  backup_retention_period = var.backup_retention_period
  deletion_protection     = var.deletion_protection
  skip_final_snapshot     = var.skip_final_snapshot

  tags = merge(var.tags, {
    Name = var.identifier
  })
}