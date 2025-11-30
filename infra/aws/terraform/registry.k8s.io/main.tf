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

locals {
  // aws ec2 describe-regions --all-regions --query "Regions[].RegionName" --output json | jq .[] | awk '{print $0","}' | sort --version-sort
  regions = [
    "af-south-1",
    # "ap-east-1",
    # "ap-east-2",
    "ap-northeast-1",
    # "ap-northeast-2",
    # "ap-northeast-3",
    "ap-southeast-1",
    "ap-southeast-2",
    # "ap-southeast-3",
    # "ap-southeast-4",
    # "ap-southeast-5",
    # "ap-southeast-6",
    # "ap-southeast-7",
    "ap-south-1",
    # "ap-south-2",
    # "ca-central-1",
    # "ca-west-1",
    "eu-central-1",
    # "eu-central-2",
    # "eu-north-1",
    "eu-south-1",
    # "eu-south-2",
    "eu-west-1",
    # "eu-west-2",
    "eu-west-3",
    # "il-central-1",
    # "me-central-1",
    # "me-south-1",
    # "mx-central-1",
    # "sa-east-1",
    "us-east-1",
    "us-east-2",
    "us-west-1",
    "us-west-2",
  ]
}

module "us-east-2" {
  // This is the authoritative bucket where objects are initially uploaded to
  source                      = "./s3"
  region                      = "us-east-2"
  prefix                      = var.prefix
  s3_replication_iam_role_arn = "arn:aws:iam::513428760722:role/registry.k8s.io_s3writer"
  s3_replication_rules = [
    for idx, region in local.regions :
    {
      id                               = "registry-k8s-io-us-east-2-to-registry-k8s-io-${region}"
      status                           = "Enabled"
      priority                         = idx + 1 # priorities start at 1
      destination_bucket_arn           = module.s3_buckets[region].bucket_arn
      destination_bucket_storage_class = "STANDARD"
    }
    // exclude the source region itself
    if region != "us-east-2"
  ]
}

module "s3_buckets" {
  for_each = setsubtract(toset(local.regions), ["us-east-2"])
  source   = "./s3"
  region   = each.key

  prefix = var.prefix
}
