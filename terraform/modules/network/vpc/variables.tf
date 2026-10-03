variable "name" {
  description = "Prefixo usado no nome da VPC e dos recursos compartilhados"
  type        = string
}

variable "cidr" {
  description = "CIDR da VPC"
  type        = string
}

variable "subnets" {
  description = "Mapa de subnets: a chave vira o nome. tier = public | eks | db"
  type = map(object({
    cidr = string
    az   = string
    tier = string
  }))
}