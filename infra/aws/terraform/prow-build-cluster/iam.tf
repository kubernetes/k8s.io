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

###############################################
# IAM access
###############################################

data "aws_iam_user" "user_xmudrii" {
  user_name = "xmudrii"
}
data "aws_iam_user" "user_pprzekwa" {
  user_name = "pprzekwa"
}

resource "aws_iam_role" "iam_cluster_admin" {
  name        = "${local.canary_prefix}Prow-Cluster-Admin"
  description = "IAM role used to delegate access to ${local.canary_prefix}prow-build-cluster"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : [
            data.aws_iam_user.user_xmudrii.arn,
            data.aws_iam_user.user_pprzekwa.arn,
          ]
        },
        "Action" : "sts:AssumeRole",
        "Condition" : {}
      }
    ]
  })
}

# Give administrator access to the admin IAM role so it can be used with Terraform.
resource "aws_iam_role_policy_attachment" "iam_policy_cluster_admin" {
  role       = aws_iam_role.iam_cluster_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
