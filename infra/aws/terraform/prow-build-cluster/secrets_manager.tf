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

data "aws_iam_policy_document" "secretsmanager_read" {
  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
  }
}

resource "aws_iam_policy" "secretsmanager_read" {
  name   = "secretsmanager_read"
  path   = "/"
  policy = data.aws_iam_policy_document.secretsmanager_read.json
}

# We allow ESO pods in the Prow control plane cluster to read from AWS Secrets Manager.
resource "aws_iam_role_policy" "eso_eks_admin" {
  name = "eso_read_policy"
  role = aws_iam_role.eso_read.id

  policy = data.aws_iam_policy_document.secretsmanager_read.json
}
