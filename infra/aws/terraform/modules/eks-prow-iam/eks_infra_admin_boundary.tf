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

# TODO(pkprzekwas): remove after replacing boundary name in EKS cluster roles and applying changes.
resource "aws_iam_policy" "provisioner_permission_boundary" {
  name        = "ProvisionerPermissionBoundary"
  description = "Permission boundary for terraform operator roles."
  policy      = data.aws_iam_policy_document.eks_resources_permission_boundary_doc.json
  tags        = var.tags
}
