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

// This configures Google GKE cluster OIDC issuer as an Identity
// Provider (IdP), and allows the list of audiences specified.
resource "aws_iam_openid_connect_provider" "google_prow_idp" {
  provider = aws.kops-infra-ci


  url            = "https://container.googleapis.com/v1/projects/k8s-prow/locations/us-central1-f/clusters/prow"
  client_id_list = ["sts.amazonaws.com"]

  # AWS wants the thumbprint of the the top intermediate certificate authority.
  thumbprint_list = [
    # GlobalSign root certificate (Google Managed Certficates)
    "08745487e891c19e3078c1f2a07e452950ef36f6"
  ]


  tags = merge(var.tags, var.janitor_tags, {
    "region" = data.aws_region.current.region
  })
}
