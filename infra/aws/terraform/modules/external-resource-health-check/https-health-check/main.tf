/*
Copyright 2023 The Kubernetes Authors.

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
  prefix = "external"
}

resource "aws_route53_health_check" "this" {
  type              = "HTTPS"
  reference_name    = "${local.prefix}-${var.name}"
  failure_threshold = var.failure_threshold
  request_interval  = var.request_interval
  fqdn              = var.fqdn
  port              = var.port
  resource_path     = var.resource_path == "" ? null : var.resource_path
  disabled          = var.disabled
  regions           = var.regions
}

resource "aws_cloudwatch_metric_alarm" "this" {
  alarm_name          = "${local.prefix}-${var.name}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = var.alarm_period
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "This Alarm monitors the healthcheck status of ${local.prefix}-${var.name}"
  alarm_actions       = [var.sns_arn]
}
