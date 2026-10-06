data "aws_caller_identity" "current" {}

provider "aws" {
  region = var.aws_region
  profile = "fiapaws"

  assume_role {
    role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"
  }

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}