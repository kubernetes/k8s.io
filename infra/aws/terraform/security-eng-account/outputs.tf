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

output "cloudtrail_trail_arn" {
  value = aws_cloudtrail.organizational_trail.arn
}

output "cloudwatch_log_group_arn" {
  value       = aws_cloudwatch_log_group.cloudtrail.arn
  description = "CloudTrail CloudWatch log group ARN"
}

output "sns_topic_arn" {
  value       = aws_sns_topic.cloudtrail.arn
  description = "CloudTrail SNS topic ARN"
}
