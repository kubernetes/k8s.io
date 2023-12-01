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

terraform {
  backend "s3" {
    bucket = "k8s-infra-kops-ci-tf-state"
    region = "us-east-2"
    key    = "kops-infra-ci/terraform.tfstate"
    // TODO(ameukam): stop used hardcoded account id. Preferably use SSO user
    role_arn     = "arn:aws:iam::808842816990:role/OrganizationAccountAccessRole"
    session_name = "kops-infra-ci"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.29.0"
    }
  }
}
