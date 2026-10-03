variable "repository_names" {
  description = "Lista de nomes dos repositórios ECR"
  type        = list(string)
}

variable "image_tag_mutability" {
  description = "MUTABLE ou IMMUTABLE"
  type        = string
  default     = "IMMUTABLE"
}

variable "scan_on_push" {
  description = "Habilita scan de vulnerabilidades ao fazer push"
  type        = bool
  default     = true
}

variable "max_image_count" {
  description = "Quantidade de imagens mantidas por repositório (lifecycle)"
  type        = number
  default     = 10
}

variable "tags" {
  description = "Tags aplicadas aos recursos"
  type        = map(string)
  default     = {}
}