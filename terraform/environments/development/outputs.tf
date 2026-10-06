# ---- S3 outputs
output "aws_s3_bucket" {
  value = module.s3.s3_bucket_name
}

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
