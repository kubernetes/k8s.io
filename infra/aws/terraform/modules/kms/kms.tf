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

data "aws_iam_policy_document" "kms_key_resource_policy" {
  override_policy_documents = [var.policy]
}

resource "aws_kms_key" "main" {
  description             = var.description
  deletion_window_in_days = var.deletion_window_in_days
  is_enabled              = true
  enable_key_rotation     = var.enable_key_rotation
  policy                  = data.aws_iam_policy_document.kms_key_resource_policy.json
  tags                    = var.tags
}

resource "aws_kms_alias" "main" {
  name          = "alias/${var.name}"
  target_key_id = aws_kms_key.main.key_id
}
