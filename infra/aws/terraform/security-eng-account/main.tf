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

module "cloutrail_kms" {
  providers = {
    aws = aws.security-eng
  }

  source      = "../modules/kms"
  name        = format("%s-%s", var.org_name, "cloudtrail_kms_key")
  description = "Encryption Key for CloudTrail logs"
  tags        = var.tags
}

resource "aws_ebs_encryption_by_default" "main" {
  provider = aws.security-eng
  enabled  = true
}

resource "aws_s3_account_public_access_block" "default" {
  provider                = aws.security-eng
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
