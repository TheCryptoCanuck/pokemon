# AviQuest Cloud Infrastructure
# Main Terraform configuration for AWS backend services

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # Configure per environment in environments/<env>/backend.hcl
    # terraform init -backend-config=environments/<env>/backend.hcl
    key = "aviquest/terraform.tfstate"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "AviQuest"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# --- CDN Module: S3 + CloudFront for bird assets ---
module "cdn" {
  source      = "./modules/cdn"
  environment = var.environment
  domain_name = var.domain_name
}

# --- Database Module: DynamoDB tables ---
module "database" {
  source      = "./modules/database"
  environment = var.environment
}

# --- Auth Module: Cognito user pool ---
module "auth" {
  source      = "./modules/auth"
  environment = var.environment
  app_name    = "AviQuest"
}

# --- API Module: API Gateway + Lambda ---
module "api" {
  source              = "./modules/api"
  environment         = var.environment
  cognito_user_pool_arn = module.auth.user_pool_arn
  birds_table_arn     = module.database.birds_table_arn
  birds_table_name    = module.database.birds_table_name
  users_table_arn     = module.database.users_table_arn
  users_table_name    = module.database.users_table_name
  assets_bucket_arn   = module.cdn.assets_bucket_arn
  assets_bucket_name  = module.cdn.assets_bucket_name
}

# --- Monitoring Module: CloudWatch dashboards & alarms ---
module "monitoring" {
  source           = "./modules/monitoring"
  environment      = var.environment
  api_name         = module.api.api_gateway_name
  lambda_functions = module.api.lambda_function_names
}
