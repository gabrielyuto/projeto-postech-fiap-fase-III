terraform {
  backend "s3" {
    bucket       = "toggle-master-tfstate-prod"
    key          = "production/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}