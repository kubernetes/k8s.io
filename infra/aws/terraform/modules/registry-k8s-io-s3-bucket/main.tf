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

data "aws_region" "current" {}

locals {
  prefix      = "k8s-infra"
  bucket_name = format("%v-registry-k8s-io-%s", local.prefix, data.aws_region.current.name)
}

module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "3.15.1"

  bucket = base64sha256(local.bucket_name)
  acl    = "public-read"

  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"

  metric_configuration = [
    {
      name = local.bucket_name
    }
  ]

  versioning = {
    enabled = true
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }
}
