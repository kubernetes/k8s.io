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

variable "account_name" {
  description = "A friendly name for the member account."
}

variable "email" {
  description = "The email address of the owner to assign to the new member account"
}

variable "iam_user_access_to_billing" {
  default     = "DENY"
  description = "If set to `ALLOW`, the new account enables IAM users to access account billing information if they have the required permissions. If set to `DENY`, then only the root user of the new account can access account billing information."
}

variable "parent_id" {
  default     = null
  description = "Parent Organizational Unit ID or Root ID for the account"
}

variable "role_name" {
  default     = null # Use AWS default, ie OrganizationAccountAccessRole
  description = "The name of an IAM role that Organizations automatically preconfigures in the new member account. This role trusts the master account, allowing users in the master account to assume the role, as permitted by the master account administrator. The role has administrator permissions in the new member account. The Organizations API provides no method for reading this information after account creation, so Terraform cannot perform drift detection on its value and will always show a difference for a configured value after import unless `ignore_changes` is used."
}

variable "tags" {
  default     = {}
  description = "Key-value mapping of resource tags."
}

variable "sso_instance_arn" {
  default     = "arn:aws:sso:::instance/ssoins-7223259e1ca869d2"
  description = "The ARN of the SSO Instance."
}

variable "identity_store_id" {
  default     = "d-9067aa4632"
  type        = string
  description = "The Identity Store ID associated with the Single Sign-On Instance."
}

variable "permissions_map" {
  default     = {}
  type        = map(any)
  description = "A map of permissions"
}
