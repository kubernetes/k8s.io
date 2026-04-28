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

output "eks_infra_admin_role_arn" {
  description = "ARN of the EKS admin role."
  value       = aws_iam_role.eks_infra_admin.arn
}

output "eks_infra_viewer_role_arn" {
  description = "ARN of the EKS viewer role."
  value       = aws_iam_role.eks_viewer.arn
}

output "eks_infra_admin_permission_boundary" {
  description = "ARN of the permission boundary enforcing EKSResourcePermissionBounday on EKS IAM resources."
  value       = aws_iam_role.eks_infra_admin.arn
}

output "eks_resources_permission_boundary" {
  description = "ARN of the permission boundary enfored on EKS IAM resources."
  value       = aws_iam_policy.eks_resources_permission_boundary.arn
}
