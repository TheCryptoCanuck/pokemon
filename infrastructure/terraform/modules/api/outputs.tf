output "api_endpoint" {
  description = "API Gateway endpoint URL"
  value       = aws_apigatewayv2_stage.main.invoke_url
}

output "api_gateway_name" {
  description = "API Gateway name"
  value       = aws_apigatewayv2_api.main.name
}

output "lambda_function_names" {
  description = "List of Lambda function names"
  value       = [aws_lambda_function.birds_api.function_name, aws_lambda_function.users_api.function_name]
}
