output "repository_urls" {
  description = "Mapa nome => URL do repositório"
  value       = { for k, v in aws_ecr_repository.this : k => v.repository_url }
}

output "repository_arns" {
  description = "Mapa nome => ARN do repositório"
  value       = { for k, v in aws_ecr_repository.this : k => v.arn }
}

output "repository_names" {
  description = "Mapa nome => nome completo de cada repositório"
  value       = { for k, r in aws_ecr_repository.this : k => r.name }
}