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

locals {
  external_ips = {
    gcsweb = {
      name = "gcsweb-k8s-io",
    },
    canary = {
      name = "k8s-io-ingress-canary",
    },
    canary-v6 = {
      name = "k8s-io-ingress-canary-v6",
      ipv6 = true
    },
    canary-packages = {
      name = "k8s-io-packages-ingress-canary",
    },
    canary-packages-v6 = {
      name = "k8s-io-packages-ingress-canary-v6",
      ipv6 = true
    },
    cs = {
      name = "cs-k8s-io-ingress",
      description = "Used for cs-canary.k8s.io"
    },
    elections = {
      name        = "k8s-io-elections",
      description = "Used for elections.k8s.io"
    },
    infra-prow = {
      name = "k8s-infra-prow",
    },
    infra-prow-v6 = {
      name = "k8s-infra-prow-v6",
      ipv6 = true
    },
    ingress-prod = {
      name = "k8s-io-ingress-prod",
    },
    ingress-prod-v6 = {
      name = "k8s-io-ingress-prod-v6",
      ipv6 = true
    },
    ingress-packages-prod = {
      name = "k8s-io-packages-ingress-prod",
    },
    ingress-packages-prod-v6 = {
      name = "k8s-io-packages-ingress-prod-v6",
      ipv6 = true
    },
    perf-dash = {
      name = "perf-dash-k8s-io-ingress-prod",
    },
    slack = {
      name = "slack-infra-ingress-prod",
    },
    triage-party-release = {
      name        = "triage-party-release-ingress-prod",
      description = "IP for aaa cluster Ingress"
    },
    triage-party-cli = {
      name        = "triage-party-cli-ingress-prod",
      description = "IP for aaa cluster Ingress"
    },
  }
}

resource "google_compute_global_address" "k8s_io" {
  project      = data.google_project.project.project_id
  for_each     = local.external_ips
  name         = each.value.name
  description  = lookup(each.value, "description", null)
  address_type = "EXTERNAL"
  ip_version   = lookup(each.value, "ipv6", false) ? "IPV6" : "IPV4"
}
