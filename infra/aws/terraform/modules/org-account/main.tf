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

resource "aws_organizations_account" "this" {
  # Names cannot be changed. It will trigger a deletion of the account, which may fail due to a
  # ConstraintViolationException error or similar
  name = var.account_name

  # Email must be unique across AWS as a whole
  email = var.email

  iam_user_access_to_billing = var.iam_user_access_to_billing
  parent_id                  = var.parent_id

  # Gives the primary account access to the new account
  role_name = var.role_name

  tags = var.tags

  # There is not an AWS Organizations API for reading those fields so ignoring them is required to prevent future errors
  lifecycle {
    ignore_changes = [
      email,
      iam_user_access_to_billing,
      name,
      role_name
    ]
  }
}
