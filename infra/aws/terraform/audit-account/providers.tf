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

provider "aws" {
  region = "us-east-2"
  alias  = "management"
}

provider "aws" {
  alias  = "audit"
  region = "us-east-2"

  assume_role {
    role_arn     = "arn:aws:iam::${local.audit-account-id}:role/OrganizationAccountAccessRole"
    session_name = "terraform+${data.aws_iam_session_context.whoami.session_name}"
  }
}
