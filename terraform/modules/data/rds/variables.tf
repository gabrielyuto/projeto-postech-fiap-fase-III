variable "identifier" {
  description = "Identificador da instância RDS (também usado como prefixo nos outros recursos)"
  type        = string
}

# --- Rede (vindos do módulo da VPC) ---
variable "vpc_id" {
  description = "ID da VPC onde o security group será criado"
  type        = string
}

variable "subnet_ids" {
  description = "Subnets de banco (precisam estar em pelo menos 2 AZs diferentes)"
  type        = list(string)
}

variable "allowed_cidr_blocks" {
  description = "CIDRs que podem acessar o banco (ex.: as subnets do EKS)"
  type        = list(string)
}

# --- Banco ---
variable "engine_version" {
  description = "Versão do PostgreSQL"
  type        = string
  default     = "16"
}

variable "instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_name" {
  description = "Nome do banco criado dentro da instância"
  type        = string
  default     = "app"
}

variable "db_username" {
  description = "Usuário administrador do banco"
  type        = string
  default     = "dbadmin"
}

# --- Armazenamento ---
variable "allocated_storage" {
  type    = number
  default = 20
}

variable "max_allocated_storage" {
  description = "Limite do autoscaling de disco (GB)"
  type        = number
  default     = 100
}

# --- Disponibilidade e proteção ---
variable "multi_az" {
  type    = bool
  default = false
}

variable "backup_retention_period" {
  description = "Dias de retenção dos backups automáticos"
  type        = number
  default     = 7
}

variable "deletion_protection" {
  type    = bool
  default = false
}

variable "skip_final_snapshot" {
  description = "true = apaga sem snapshot final (ok para dev; em produção use false)"
  type        = bool
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}