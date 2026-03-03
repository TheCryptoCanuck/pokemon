# API Module: API Gateway + Lambda for AviQuest backend

# --- IAM Role for Lambda ---
resource "aws_iam_role" "lambda" {
  name = "aviquest-lambda-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_dynamodb" {
  name = "aviquest-lambda-dynamodb-${var.environment}"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem",
        ]
        Resource = [
          var.birds_table_arn,
          "${var.birds_table_arn}/index/*",
          var.users_table_arn,
          "${var.users_table_arn}/index/*",
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
        ]
        Resource = [
          var.assets_bucket_arn,
          "${var.assets_bucket_arn}/*",
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# --- Lambda Functions ---

# Birds API Lambda
resource "aws_lambda_function" "birds_api" {
  function_name = "aviquest-birds-api-${var.environment}"
  role          = aws_iam_role.lambda.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  timeout       = 15
  memory_size   = 256

  filename         = data.archive_file.birds_api.output_path
  source_code_hash = data.archive_file.birds_api.output_base64sha256

  environment {
    variables = {
      BIRDS_TABLE  = var.birds_table_name
      USERS_TABLE  = var.users_table_name
      ASSETS_BUCKET = var.assets_bucket_name
      ENVIRONMENT  = var.environment
    }
  }

  tags = {
    Name = "aviquest-birds-api-${var.environment}"
  }
}

data "archive_file" "birds_api" {
  type        = "zip"
  source_dir  = "${path.module}/../../../../backend/src"
  output_path = "${path.module}/../../../../backend/dist/birds-api.zip"
}

# Users API Lambda
resource "aws_lambda_function" "users_api" {
  function_name = "aviquest-users-api-${var.environment}"
  role          = aws_iam_role.lambda.arn
  handler       = "users.handler"
  runtime       = "nodejs20.x"
  timeout       = 15
  memory_size   = 256

  filename         = data.archive_file.users_api.output_path
  source_code_hash = data.archive_file.users_api.output_base64sha256

  environment {
    variables = {
      USERS_TABLE  = var.users_table_name
      BIRDS_TABLE  = var.birds_table_name
      ENVIRONMENT  = var.environment
    }
  }

  tags = {
    Name = "aviquest-users-api-${var.environment}"
  }
}

data "archive_file" "users_api" {
  type        = "zip"
  source_dir  = "${path.module}/../../../../backend/src"
  output_path = "${path.module}/../../../../backend/dist/users-api.zip"
}

# --- API Gateway ---

resource "aws_apigatewayv2_api" "main" {
  name          = "aviquest-api-${var.environment}"
  protocol_type = "HTTP"

  cors_configuration {
    allow_headers = ["Content-Type", "Authorization"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_origins = ["*"]
    max_age       = 86400
  }

  tags = {
    Name = "aviquest-api-${var.environment}"
  }
}

resource "aws_apigatewayv2_stage" "main" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = var.environment
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      integrationError = "$context.integrationErrorMessage"
    })
  }

  default_route_settings {
    throttling_burst_limit = var.environment == "prod" ? 100 : 20
    throttling_rate_limit  = var.environment == "prod" ? 50 : 10
  }
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/apigateway/aviquest-${var.environment}"
  retention_in_days = var.environment == "prod" ? 90 : 14
}

# Cognito authorizer
resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.main.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "cognito-authorizer"

  jwt_configuration {
    audience = [aws_apigatewayv2_api.main.id]
    issuer   = "https://cognito-idp.${data.aws_region.current.name}.amazonaws.com/${var.cognito_user_pool_arn}"
  }
}

data "aws_region" "current" {}

# --- API Routes ---

# Birds routes (public — no auth required for browsing)
resource "aws_apigatewayv2_integration" "birds" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.birds_api.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_birds" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /birds"
  target    = "integrations/${aws_apigatewayv2_integration.birds.id}"
}

resource "aws_apigatewayv2_route" "get_bird" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /birds/{bird_id}"
  target    = "integrations/${aws_apigatewayv2_integration.birds.id}"
}

resource "aws_apigatewayv2_route" "get_birds_by_rarity" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /birds/rarity/{rarity}"
  target    = "integrations/${aws_apigatewayv2_integration.birds.id}"
}

# Users routes (authenticated)
resource "aws_apigatewayv2_integration" "users" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.users_api.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_profile" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "GET /users/profile"
  target             = "integrations/${aws_apigatewayv2_integration.users.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "post_collection" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "POST /users/collection"
  target             = "integrations/${aws_apigatewayv2_integration.users.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "get_collection" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "GET /users/collection"
  target             = "integrations/${aws_apigatewayv2_integration.users.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "get_leaderboard" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /leaderboard"
  target    = "integrations/${aws_apigatewayv2_integration.users.id}"
}

# Lambda permissions for API Gateway
resource "aws_lambda_permission" "birds_api" {
  statement_id  = "AllowAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.birds_api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "users_api" {
  statement_id  = "AllowAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.users_api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}
