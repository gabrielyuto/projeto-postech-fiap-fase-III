variable "aws_region" {
  description = "Região AWS"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Ambiente"
  type        = string
}

variable "project_name" {
  description = "Nome do projeto"
  type        = string
}

variable "ecr_repositories" {
  description = "Nomes dos repositórios ECR a serem criados"
  type        = list(string)
}
