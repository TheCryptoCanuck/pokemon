output "cdn_domain" {
  description = "CloudFront distribution domain for bird assets"
  value       = module.cdn.distribution_domain
}

output "api_endpoint" {
  description = "API Gateway endpoint URL"
  value       = module.api.api_endpoint
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID for mobile app configuration"
  value       = module.auth.user_pool_id
}

output "cognito_client_id" {
  description = "Cognito App Client ID for mobile app configuration"
  value       = module.auth.client_id
}

output "assets_bucket" {
  description = "S3 bucket name for bird image/audio assets"
  value       = module.cdn.assets_bucket_name
}
