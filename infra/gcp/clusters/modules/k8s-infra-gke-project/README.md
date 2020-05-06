# `k8s-infra-gke-project` terraform module

This terraform module defines a GCP project intended to host a GKE cluster
as created by the `k8s-infra-gke-cluster` module:
- Project is associated with CNCF org
- Project is linked to CNCF billing account
- Services necessary to support `k8s-infra-gke-cluster` are enabled
- Some default IAM bindings are added:
  - k8s-infra-cluster-admins@ gets `roles/compute.viewer`, `roles/container.admin`, `roles/ServiceAccountLister`
  - gke-security-groups@ gets `roles/container.clusterViewer`
