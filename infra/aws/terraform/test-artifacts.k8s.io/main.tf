/*
Copyright 2022 The Kubernetes Authors.

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


module "us-east-2" {
  source = "./s3"

  providers = {
    aws = aws.us-east-2
  }

  prefix = var.prefix

  s3_replication_iam_role_arn = aws_iam_role.replication.arn

  s3_replication_rules = [for idx, region in var.s3_replica_regions :
    {
      id                               = "us-east-2-to-${region}"
      status                           = "Enabled"
      priority                         = idx + 1
      destination_bucket_arn           = "arn:aws:s3:::${var.prefix}artifacts-k8s-io-${region}"
      destination_bucket_storage_class = "STANDARD"
    }
  ]
}

module "eu-west-2" {
  source = "./s3"

  providers = {
    aws = aws.eu-west-2
  }

  prefix = var.prefix
}

module "ap-southeast-1" {
  source = "./s3"

  providers = {
    aws = aws.ap-southeast-1
  }

  prefix = var.prefix
}
