variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "cognito_user_pool_arn" {
  description = "Cognito User Pool ARN for API authorization"
  type        = string
}

variable "birds_table_arn" {
  description = "DynamoDB birds table ARN"
  type        = string
}

variable "birds_table_name" {
  description = "DynamoDB birds table name"
  type        = string
}

variable "users_table_arn" {
  description = "DynamoDB users table ARN"
  type        = string
}

variable "users_table_name" {
  description = "DynamoDB users table name"
  type        = string
}

variable "assets_bucket_arn" {
  description = "S3 assets bucket ARN"
  type        = string
}

variable "assets_bucket_name" {
  description = "S3 assets bucket name"
  type        = string
}
