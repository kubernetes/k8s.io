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

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {}

data "aws_iam_role" "eks_infra_admin" {
  name = "EKSInfraAdmin"
}

data "aws_iam_role" "eks_infra_viewer" {
  name = "EKSInfraViewer"
}

data "aws_iam_user" "eks_cluster_viewers" {
  count     = length(var.eks_cluster_viewers)
  user_name = var.eks_cluster_viewers[count.index]
}

data "aws_iam_user" "eks_cluster_admins" {
  count     = length(var.eks_cluster_admins)
  user_name = var.eks_cluster_admins[count.index]
}

data "aws_iam_policy" "eks_resources_permission_boundary" {
  name        = "EKSResourcesPermissionBoundary"
  path_prefix = "/boundary/"
}
