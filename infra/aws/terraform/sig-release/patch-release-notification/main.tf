/*
Copyright 2024 The Kubernetes Authors.

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

provider "aws" {
  region = var.region
}

resource "aws_sesv2_email_identity" "sig_release_email_identity" {
  email_identity = var.email_identity
}

resource "aws_iam_role" "lambda_ses_role" {
  name = "lambda_ses_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_ses_policy" {
  name        = "lambda_ses_policy"
  description = "IAM policy for Lambda to access SES"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

resource "aws_ecr_repository" "repo" {
  name                 = var.repository
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }
}

resource "aws_ecr_repository" "cherry_pick_notification_repo" {
  name                 = "${var.repository}/patch-release-notification"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }
}

resource "ko_build" "cherry_pick_notification_image" {
  repo        = aws_ecr_repository.cherry_pick_notification_repo.repository_url
  base_image  = "public.ecr.aws/lambda/provided:al2023"
  working_dir = "${path.module}/../../../../../../release/cmd/patch-release-notification"
  importpath  = "k8s.io/release/cmd/patch-release-notification"
}

resource "aws_iam_role_policy_attachment" "lambda_ses_policy_attachment" {
  role       = aws_iam_role.lambda_ses_role.name
  policy_arn = aws_iam_policy.lambda_ses_policy.arn
}

resource "aws_lambda_function" "cherry_pick_notification" {
  function_name = "patch-release-notification"
  role          = aws_iam_role.lambda_ses_role.arn
  image_uri     = ko_build.cherry_pick_notification_image.image_ref
  package_type  = "Image"

  environment {
    variables = {
      FROM_EMAIL    = var.email_identity
      TO_EMAIL      = var.to_email
      SCHEDULE_PATH = var.schedule_path
      DAYS_TO_ALERT = var.days_to_alert
      NO_MOCK       = var.no_mock
      AWS_REGION    = var.region
    }
  }
}

resource "aws_cloudwatch_event_rule" "trigger_lambda_cron" {
  name                = "trigger-patch-release-notification-cron"
  description         = "Trigger Lambda function on a schedule"
  schedule_expression = "cron(0 16 * * ? *)" # Example cron expression to run at 16:00 PM UTC every day
}

resource "aws_cloudwatch_event_target" "trigger_lambda_target" {
  rule      = aws_cloudwatch_event_rule.trigger_lambda_cron.name
  target_id = "send_email_lambda"
  arn       = aws_lambda_function.cherry_pick_notification.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_to_invoke_lambda" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cherry_pick_notification.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.trigger_lambda_cron.arn
}
