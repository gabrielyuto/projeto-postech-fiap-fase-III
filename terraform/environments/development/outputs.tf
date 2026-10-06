# ---- ECR outputs
output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

output "ecr_repository_arns" {
  value = module.ecr.repository_arns
}

output "ecr_repository_names" {
  value = module.ecr.repository_names
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket"        # Descrição do output
  value       = aws_s3_bucket.artifacts.bucket # Valor: nome do bucket
}
