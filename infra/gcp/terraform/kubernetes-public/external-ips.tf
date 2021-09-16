/*
Copyright 2021 The Kubernetes Authors.

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
 
/*
This file defines all the external IP addresses in kubernetes-public
*/

resource "google_compute_global_address" "k8s_io" {
  project       = data.google_project.project.project_id
  for_each = {
    // used by gcsweb.k8s.io
    gcsweb = {
      name = "gcsweb-k8s-io",
      description = null
      address_type = "EXTERNAL",
      ip_version = "IPV4"
    },
    // used by canary.k8s.io
    canary = {
      name = "k8s-io-ingress-canary",
      description = null
      address_type = "EXTERNAL",
      ip_version = "IPV4"
    },
    // used by canary.k8s.io (IPv6)
    canary-v6 = {
      name = "k8s-io-ingress-canary-v6",
      description = null
      address_type = "EXTERNAL",
      ip_version = "IPV6"
    },
    // used by cs.k8s.io
    cs = {
      name = "cs-k8s-io-ingress",
      description = null
      address_type = "EXTERNAL",
      ip_version = "IPV4"
    },
    // used by k8s-infra-prow.k8s.io
    infra-prow = {
      name = "k8s-infra-prow",
      description = null
      address_type = "EXTERNAL",
      ip_version = "IPV4"
    },
    // used by k8s-infra-prow.k8s.io (IPv6)
    infra-prow-v6 = {
      name = "k8s-infra-prow-v6",
      description = null
      address_type = "EXTERNAL",
      ip_version = "IPV6"
    },
    // used by k8s.io
    ingress-prod = {
      name = "k8s-io-ingress-prod",
      description = null
      address_type = "EXTERNAL",
      ip_version = "IPV4"
    },
    // used by k8s.io (IPv6)
    ingress-prod-v6 = {
      name = "k8s-io-ingress-prod-v6",
      description = null
      address_type = "EXTERNAL",
      ip_version = "IPV6"
    },
    // used by perf-dash.k8s.io
    perf-dash = {
      name = "perf-dash-k8s-io-ingress-prod",
      description = null
      address_type = "EXTERNAL",
      ip_version = "IPV4"
    },
    // used by sippy.k8s.io
    sippy = {
      name = "sippy-ingress-prod",
      description  = "IP for aaa cluster Ingress"
      address_type = "EXTERNAL",
      ip_version = "IPV4"
    },
    // used by slack.k8s.io
    slack = {
      name = "slack-infra-ingress-prod",
      description = null
      address_type = "EXTERNAL",
      ip_version = "IPV4"
    },
    // used by release.triage.k8s.io
    triage-party-release = {
      name = "triage-party-release-ingress-prod",
      description  = "IP for aaa cluster Ingress"
      address_type = "EXTERNAL",
      ip_version = "IPV4"
    },
  }

  name          = each.value.name
  description   = each.value.description
  address_type  = each.value.address_type
  ip_version    = each.value.ip_version
}
