# Auth Module: Cognito user pool for AviQuest player authentication

resource "aws_cognito_user_pool" "main" {
  name = "aviquest-users-${var.environment}"

  # Username config
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  username_configuration {
    case_sensitive = false
  }

  # Password policy
  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = false
    temporary_password_validity_days = 7
  }

  # Schema attributes
  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true

    string_attribute_constraints {
      min_length = 5
      max_length = 256
    }
  }

  schema {
    name                = "username"
    attribute_data_type = "String"
    required            = false
    mutable             = true

    string_attribute_constraints {
      min_length = 3
      max_length = 30
    }
  }

  # Account recovery
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # Email config (use Cognito default for dev/staging, SES for prod)
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # MFA (optional for users)
  mfa_configuration = "OPTIONAL"

  software_token_mfa_configuration {
    enabled = true
  }

  tags = {
    Name = "aviquest-auth-${var.environment}"
  }
}

# App client for the Flutter mobile app
resource "aws_cognito_user_pool_client" "mobile" {
  name         = "aviquest-mobile-${var.environment}"
  user_pool_id = aws_cognito_user_pool.main.id

  # Public client (no secret) for mobile apps
  generate_secret = false

  # Auth flows
  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_PASSWORD_AUTH",
  ]

  # Token validity
  access_token_validity  = 1  # hours
  id_token_validity      = 1  # hours
  refresh_token_validity = 30 # days

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  # Prevent user existence errors (security best practice)
  prevent_user_existence_errors = "ENABLED"

  supported_identity_providers = ["COGNITO"]
}
