output "distribution_domain" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.assets.domain_name
}

output "distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.assets.id
}

output "assets_bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.assets.id
}

output "assets_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.assets.arn
}
