variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "api_name" {
  description = "API Gateway name"
  type        = string
}

variable "lambda_functions" {
  description = "List of Lambda function names to monitor"
  type        = list(string)
}
