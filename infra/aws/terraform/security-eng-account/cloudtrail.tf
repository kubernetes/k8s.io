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

resource "aws_cloudtrail" "organizational_trail" {
  provider                      = aws.audit
  name                          = local.cloudtrail_trail_name
  s3_bucket_name                = aws_s3_bucket.cloutrail_logs.id
  is_multi_region_trail         = true
  is_organization_trail         = true
  enable_log_file_validation    = true
  include_global_service_events = true

  tags = var.tags

  depends_on = [
    aws_s3_bucket_policy.cloudtrail_access,
  ]
}

# CloudWatch log groups & log streams for CloudTrail
resource "aws_cloudwatch_log_group" "cloudtrail" {
  provider   = aws.logging
  name       = "cloudtrail"
  kms_key_id = module.cloutrail_kms.id
  tags       = var.tags
}

resource "aws_cloudwatch_log_stream" "cloudtrail_stream" {
  provider       = aws.logging
  name           = data.aws_caller_identity.current.account_id
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
}
