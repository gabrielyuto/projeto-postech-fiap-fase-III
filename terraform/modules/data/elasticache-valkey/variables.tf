variable "name" {
  description = "Identificador do cache (minúsculas, números e hifens; até 40 caracteres)"
  type        = string
}

variable "vpc_id" {
  description = "ID da VPC onde o security group será criado"
  type        = string
}

variable "subnet_ids" {
  description = "Subnets onde os nós do cache podem rodar"
  type        = list(string)
}

variable "allowed_cidr_blocks" {
  description = "CIDRs que podem acessar o cache (ex.: as subnets do EKS)"
  type        = list(string)
}

variable "engine_version" {
  description = "Versão do Valkey"
  type        = string
  default     = "8.0"
}

variable "node_type" {
  type    = string
  default = "cache.t3.micro"
}

variable "num_cache_clusters" {
  description = "Número de nós (1 = só o primário; 2+ adiciona réplicas)"
  type        = number
  default     = 1
}