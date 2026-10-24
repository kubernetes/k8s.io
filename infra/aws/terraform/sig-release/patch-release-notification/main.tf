/*
Copyright 2026 The Kubernetes Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

locals {
  name = "patch-release-notification"
}

data "aws_caller_identity" "current" {}

resource "aws_sesv2_email_identity" "sender" {
  email_identity = var.sender_email
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${local.name}"
  retention_in_days = 90
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = local.name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "lambda" {
  statement {
    sid       = "SendEmail"
    actions   = ["ses:SendEmail"]
    resources = [aws_sesv2_email_identity.sender.arn]
  }

  statement {
    sid       = "WriteLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.this.arn}:*"]
  }
}

resource "aws_iam_role_policy" "lambda" {
  name   = local.name
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda.json
}

resource "aws_lambda_function" "this" {
  function_name = local.name
  description   = "Emails the cherry-pick deadline for upcoming Kubernetes patch releases"
  role          = aws_iam_role.lambda.arn
  package_type  = "Image"
  image_uri     = var.image_uri
  architectures = ["arm64"]
  memory_size   = 128
  timeout       = 60

  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.this.name
  }

  # AWS_REGION is reserved and set by the Lambda runtime.
  environment {
    variables = {
      FROM_EMAIL    = var.sender_email
      TO_EMAIL      = var.recipient_email
      SCHEDULE_PATH = var.schedule_path
      DAYS_TO_ALERT = var.days_to_alert
      NO_MOCK       = var.no_mock
    }
  }

  depends_on = [
    aws_iam_role_policy.lambda,
    aws_cloudwatch_log_group.this,
  ]
}

# A failed run is retried, but a reminder sent hours late is not useful.
resource "aws_lambda_function_event_invoke_config" "this" {
  function_name                = aws_lambda_function.this.function_name
  maximum_retry_attempts       = 2
  maximum_event_age_in_seconds = 3600
}

resource "aws_cloudwatch_event_rule" "schedule" {
  name                = local.name
  description         = "Daily trigger for ${local.name}"
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule = aws_cloudwatch_event_rule.schedule.name
  arn  = aws_lambda_function.this.arn
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule.arn
}

# Alert when a run fails, otherwise a missed reminder goes unnoticed.
resource "aws_sns_topic" "alerts" {
  count = var.alert_email == "" ? 0 : 1

  name = "${local.name}-alerts"
}

resource "aws_sns_topic_subscription" "alerts" {
  count = var.alert_email == "" ? 0 : 1

  topic_arn = aws_sns_topic.alerts[0].arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "errors" {
  count = var.alert_email == "" ? 0 : 1

  alarm_name          = "${local.name}-errors"
  alarm_description   = "${local.name} Lambda failed, check the /aws/lambda/${local.name} logs"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  dimensions          = { FunctionName = aws_lambda_function.this.function_name }
  statistic           = "Sum"
  period              = 3600
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts[0].arn]
}
