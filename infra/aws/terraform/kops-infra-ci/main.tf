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
}

## Used by kOps to store the state of the kOps created
resource "aws_s3_bucket" "kops_state_store" {
  provider = aws.kops-infra-ci
  bucket   = "k8s-kops-ci-prow-state-store"
  tags     = var.tags
}

resource "aws_s3_bucket_ownership_controls" "kops_state_store" {
  provider = aws.kops-infra-ci
  bucket   = aws_s3_bucket.kops_state_store.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}


## Used by kOps for hosting OIDC documents
resource "aws_s3_bucket" "kops_oidc_store" {
  provider = aws.kops-infra-ci
  bucket   = "k8s-kops-ci-prow"
  tags     = var.tags
}

resource "aws_s3_bucket_ownership_controls" "kops_oidc_store" {
  provider = aws.kops-infra-ci
  bucket   = aws_s3_bucket.kops_oidc_store.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "kops_oidc_store" {
  provider = aws.kops-infra-ci
  bucket   = aws_s3_bucket.kops_oidc_store.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "kops_oidc_store" {
  provider = aws.kops-infra-ci
  bucket   = aws_s3_bucket.kops_oidc_store.id
  acl      = "public-read"
}
