# -- General configuration for the production environment
aws_region   = "us-east-1"
project_name = "toggle-master"
environment  = "development"

## -- ECR configuration
ecr_repositories = [
  "analytics-service",
  "auth-service",
  "evaluation-service",
  "flag-service",
  "targeting-service"
]

