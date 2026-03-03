output "birds_table_name" {
  description = "DynamoDB birds table name"
  value       = aws_dynamodb_table.birds.name
}

output "birds_table_arn" {
  description = "DynamoDB birds table ARN"
  value       = aws_dynamodb_table.birds.arn
}

output "users_table_name" {
  description = "DynamoDB users table name"
  value       = aws_dynamodb_table.users.name
}

output "users_table_arn" {
  description = "DynamoDB users table ARN"
  value       = aws_dynamodb_table.users.arn
}

output "collections_table_name" {
  description = "DynamoDB collections table name"
  value       = aws_dynamodb_table.collections.name
}

output "collections_table_arn" {
  description = "DynamoDB collections table ARN"
  value       = aws_dynamodb_table.collections.arn
}
