# `k8s-infra-gke-nodepool` terraform module

This terraform module defines a GKE Nodepool for k8s-infra use:
- It is expected the cluster has been provisioned using the `k8s-infra-gke-cluster` module
- Workload identity is enabled by default for this nodepool
