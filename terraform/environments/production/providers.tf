provider "aws" {
  region = var.aws_region
  profile = "fiapaws"

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}