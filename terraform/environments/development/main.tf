module "s3" {
  source = "../../modules/data/s3"

  bucket_name = "${var.project_name}-${var.environment}-artifacts"

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

module "ecr" {
  source = "../../modules/ecr"

  repository_names     = var.ecr_repositories
  image_tag_mutability = "IMMUTABLE"
  scan_on_push         = true
  max_image_count      = 5

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}