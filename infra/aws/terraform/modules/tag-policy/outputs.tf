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

output "tag_policy_id" {
  description = "The unique identifier (ID) of the tag policy"
  value       = aws_organizations_policy.this.id
}

output "scp_require_tag_id" {
  description = "The unique identifier (ID) of the request tag policy"
  value       = aws_organizations_policy.request_tag.id
}

output "scp_deny_tag_deletion_id" {
  description = "The unique identifier (ID) of the deny tag policy"
  value       = aws_organizations_policy.deny_tag_deletion.id
}

output "name" {
  description = "TODO - name does not quite match the value"
  value       = local.selected_services
}
