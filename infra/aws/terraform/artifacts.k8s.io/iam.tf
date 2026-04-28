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

# Recognize federated identities from the prow trusted cluster
resource "aws_iam_openid_connect_provider" "k8s-infra-trusted-cluster" {
  url             = "https://container.googleapis.com/v1/projects/k8s-infra-prow-build-trusted/locations/us-central1/clusters/prow-build-trusted"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["08745487e891c19e3078c1f2a07e452950ef36f6"]
}

# s3writer iam role for artifacts management
# We allow the kubernetes service account to assume this role
resource "aws_iam_role" "artifacts-k8s-io-s3writer" {
  name = "artifacts.k8s.io_s3writer"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Federated" : aws_iam_openid_connect_provider.k8s-infra-trusted-cluster.arn
        },
        "Action" : "sts:AssumeRoleWithWebIdentity",
        "Condition" : {
          "StringEquals" : {
            "container.googleapis.com/v1/projects/k8s-infra-prow-build-trusted/locations/us-central1/clusters/prow-build-trusted:sub" : "system:serviceaccount:test-pods:k8s-infra-promoter"
          }
        }
      }
    ]
  })

  max_session_duration = 43200

  tags = {
    project = "artifacts.k8s.io"
  }
}

# Grant the s3writer IAM role permissions to write to buckets
resource "aws_iam_role_policy" "artifacts-k8s-io-s3writer-policy" {
  name = "artifacts.k8s.io_s3writer_policy"
  role = aws_iam_role.artifacts-k8s-io-s3writer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          # Object permissions
          "s3:GetObject",
          "s3:GetObjectAcl",
          "s3:GetObjectAttributes",
          "s3:GetObjectRetention",
          "s3:GetObjectTagging",
          "s3:GetObjectVersion",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionAttributes",
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionTagging",
          "s3:PutObject",

          # Bucket permissions
          "s3:GetBucketAcl",
          "s3:GetBucketLocation",
          "s3:GetReplicationConfiguration",
          "s3:ListAllMyBuckets",
          "s3:ListBucket",
          "s3:ListBucketVersions",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}
