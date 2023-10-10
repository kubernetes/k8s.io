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
module "ca_central_1" {
  providers = {
    aws = aws.ca-central-1
  }

  source = "../modules/registry-k8s-io-s3-bucket"
}

module "us_east_1" {
  providers = {
    aws = aws.us-east-1
  }

  source = "../modules/registry-k8s-io-s3-bucket"
}

module "us_east_2" {
  providers = {
    aws = aws.us-east-2
  }

  source = "../modules/registry-k8s-io-s3-bucket"
}

module "us_west_1" {
  providers = {
    aws = aws.us-west-1
  }

  source = "../modules/registry-k8s-io-s3-bucket"
}

module "us_west_2" {
  providers = {
    aws = aws.us-west-2
  }

  source = "../modules/registry-k8s-io-s3-bucket"
}
