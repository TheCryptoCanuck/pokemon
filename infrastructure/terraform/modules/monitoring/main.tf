# Monitoring Module: CloudWatch dashboards and alarms

# --- CloudWatch Dashboard ---
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "AviQuest-${var.environment}"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "API Gateway Requests"
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiName", var.api_name, { stat = "Sum", period = 300 }],
            ["AWS/ApiGateway", "4XXError", "ApiName", var.api_name, { stat = "Sum", period = 300 }],
            ["AWS/ApiGateway", "5XXError", "ApiName", var.api_name, { stat = "Sum", period = 300 }],
          ]
          view    = "timeSeries"
          region  = data.aws_region.current.name
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "API Gateway Latency"
          metrics = [
            ["AWS/ApiGateway", "Latency", "ApiName", var.api_name, { stat = "Average", period = 300 }],
            ["AWS/ApiGateway", "Latency", "ApiName", var.api_name, { stat = "p99", period = 300 }],
          ]
          view    = "timeSeries"
          region  = data.aws_region.current.name
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 24
        height = 6
        properties = {
          title = "Lambda Invocations & Errors"
          metrics = flatten([
            for fn in var.lambda_functions : [
              ["AWS/Lambda", "Invocations", "FunctionName", fn, { stat = "Sum", period = 300 }],
              ["AWS/Lambda", "Errors", "FunctionName", fn, { stat = "Sum", period = 300 }],
            ]
          ])
          view    = "timeSeries"
          region  = data.aws_region.current.name
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 24
        height = 6
        properties = {
          title = "Lambda Duration"
          metrics = [
            for fn in var.lambda_functions :
            ["AWS/Lambda", "Duration", "FunctionName", fn, { stat = "Average", period = 300 }]
          ]
          view    = "timeSeries"
          region  = data.aws_region.current.name
          period  = 300
        }
      }
    ]
  })
}

data "aws_region" "current" {}

# --- SNS Topic for Alarms ---
resource "aws_sns_topic" "alarms" {
  name = "aviquest-alarms-${var.environment}"
}

# --- CloudWatch Alarms ---

# High API error rate alarm
resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "aviquest-${var.environment}-api-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = var.environment == "prod" ? 10 : 50
  alarm_description   = "API Gateway 5XX errors exceeded threshold"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    ApiName = var.api_name
  }
}

# Lambda error alarm (per function)
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each = toset(var.lambda_functions)

  alarm_name          = "aviquest-${var.environment}-${each.value}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Lambda function ${each.value} error rate exceeded threshold"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    FunctionName = each.value
  }
}

# Lambda throttle alarm
resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  for_each = toset(var.lambda_functions)

  alarm_name          = "aviquest-${var.environment}-${each.value}-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Lambda function ${each.value} is being throttled"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    FunctionName = each.value
  }
}
