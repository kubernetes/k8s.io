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

output "cluster" {
  description = "The cluster"
  // Workaround from https://github.com/hashicorp/terraform/issues/22544#issuecomment-582974372
  // This should be either test_cluster or prod_cluster
  value       = coalescelist(
    google_container_cluster.test_cluster.*,
    google_container_cluster.prod_cluster.*
  )[0]
}

output "cluster_node_sa" {
  description = "The service_account created for the cluster's nodes"
  value       = google_service_account.cluster_node_sa
}
