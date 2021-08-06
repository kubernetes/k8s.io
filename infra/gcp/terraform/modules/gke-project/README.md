# `gke-project` terraform module

This terraform module defines a GCP project following wg-k8s-infra conventions
that is intended to host a GKE cluster created by the [`gke-cluster`] module:
- Project is associated with CNCF org
- Project is linked to CNCF billing account
- Services necessary to support [`gke-cluster`] are enabled
- Some default IAM bindings are added:
  - k8s-infra-cluster-admins@ gets `roles/compute.viewer`, `roles/container.admin`, org role [`ServiceAccountLister`]
  - gke-security-groups@ gets `roles/container.clusterViewer`

[`gke-cluster`]: /infra/gcp/terraform/modules/gke-cluster
[`gke-nodepool`]: /infra/gcp/terraform/modules/gke-nodepool
[`ServiceAccountLister`]: /infra/gcp/roles/iam.serviceAccountLister.yaml
