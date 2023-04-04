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

# This IAM configuration allows Prow GKE Clusters to assume a role on AWS.
# Provisioning those resources for canary installation is skipped.

# Recognize federated identities from the prow trusted cluster
resource "aws_iam_openid_connect_provider" "k8s_prow" {
  count = terraform.workspace == "prod" ? 1 : 0

  url             = "https://container.googleapis.com/v1/projects/k8s-prow/locations/us-central1-f/clusters/prow"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["08745487e891c19e3078c1f2a07e452950ef36f6"]
}

# We allow Prow Pods with specific service acccounts on the a particular cluster to assume this role
resource "aws_iam_role" "eks_admin" {
  count = terraform.workspace == "prod" ? 1 : 0

  name = "Prow-EKS-Admin"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Federated" : aws_iam_openid_connect_provider.k8s_prow[0].arn
        },
        "Action" : "sts:AssumeRoleWithWebIdentity",
        "Condition" : {
          "StringEquals" : {
            "container.googleapis.com/v1/projects/k8s-prow/locations/us-central1-f/clusters/prow:sub" : [
              // https://github.com/kubernetes/test-infra/tree/master/config/prow/cluster 
              // all services that load kubeconfig should be listed here
              "system:serviceaccount:default:deck",
              "system:serviceaccount:default:config-bootstrapper",
              "system:serviceaccount:default:crier",
              "system:serviceaccount:default:sinker",
              "system:serviceaccount:default:prow-controller-manager",
              "system:serviceaccount:default:hook"
            ]
          }
        }
      }
    ]
  })

  max_session_duration = 43200

}
