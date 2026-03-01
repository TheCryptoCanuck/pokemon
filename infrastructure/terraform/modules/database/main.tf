# Database Module: DynamoDB tables for AviQuest

# Birds catalog table — serves bird data to the app
resource "aws_dynamodb_table" "birds" {
  name         = "aviquest-birds-${var.environment}"
  billing_mode = var.environment == "prod" ? "PROVISIONED" : "PAY_PER_REQUEST"
  hash_key     = "bird_id"

  attribute {
    name = "bird_id"
    type = "S"
  }

  attribute {
    name = "rarity"
    type = "S"
  }

  attribute {
    name = "habitat"
    type = "S"
  }

  global_secondary_index {
    name            = "rarity-index"
    hash_key        = "rarity"
    projection_type = "ALL"

    dynamic "read_capacity" {
      for_each = var.environment == "prod" ? [1] : []
      content {}
    }
  }

  global_secondary_index {
    name            = "habitat-index"
    hash_key        = "habitat"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = var.environment == "prod"
  }

  tags = {
    Name = "aviquest-birds-${var.environment}"
  }

  lifecycle {
    prevent_destroy = false
  }
}

# User profiles and progress
resource "aws_dynamodb_table" "users" {
  name         = "aviquest-users-${var.environment}"
  billing_mode = var.environment == "prod" ? "PROVISIONED" : "PAY_PER_REQUEST"
  hash_key     = "user_id"

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "total_xp"
    type = "N"
  }

  global_secondary_index {
    name            = "leaderboard-index"
    hash_key        = "total_xp"
    projection_type = "INCLUDE"
    non_key_attributes = ["user_id", "username", "level", "collection_count"]
  }

  point_in_time_recovery {
    enabled = var.environment == "prod"
  }

  tags = {
    Name = "aviquest-users-${var.environment}"
  }
}

# User collections — tracks which birds each user has found
resource "aws_dynamodb_table" "collections" {
  name         = "aviquest-collections-${var.environment}"
  billing_mode = var.environment == "prod" ? "PROVISIONED" : "PAY_PER_REQUEST"
  hash_key     = "user_id"
  range_key    = "bird_id"

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "bird_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = var.environment == "prod"
  }

  tags = {
    Name = "aviquest-collections-${var.environment}"
  }
}
