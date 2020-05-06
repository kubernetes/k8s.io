/**
 * Copyright 2020 The Kubernetes Authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

variable "project_id" {
  description = "The id of the project, eg: my-awesome-project"
  type        = string
}

variable "project_name" {
  description = "The display name of the project, eg: My Awesome Project"
  type        = string
}

variable "cluster_admins_group" {
  description = "The group to treat as cluster admins"
  type        = string
  default     = "k8s-infra-cluster-admins@kubernetes.io"
}

variable "cluster_users_group" {
  description = "The group to treat as cluster users"
  type        = string
  default     = "gke-security-groups@kubernetes.io"
}
