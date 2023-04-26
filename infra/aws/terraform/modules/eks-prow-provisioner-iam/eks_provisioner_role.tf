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

resource "aws_iam_role" "iam_cluster_provisioner" {
  name        = "TFProwClusterProvisioner"
  description = "IAM role used to delegate access to prow-build-cluster"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : data.aws_iam_user.eks_provisioners[*].arn
        },
        "Action" : "sts:AssumeRole",
        "Condition" : {}
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_apply" {
  role       = aws_iam_role.iam_cluster_provisioner.name
  policy_arn = aws_iam_policy.prow_cluster_apply.arn
}

resource "aws_iam_role_policy_attachment" "cluster_destroy" {
  role       = aws_iam_role.iam_cluster_provisioner.name
  policy_arn = aws_iam_policy.prow_cluster_destroy.arn
}
