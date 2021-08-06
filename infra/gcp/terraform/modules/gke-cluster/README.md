# `gke-cluster` terraform module

This terraform module defines a GKE cluster following wg-k8s-infra conventions:
- GCP Service Account for nodes
- BigQuery dataset for usage metering
- GKE cluster with some useful defaults
- No nodes are provided, they are expected to come from nodepools created via the [`gke-nodepool`] module

It is assumed the GCP project for this cluster has been created via the [`gke-project`] module

If this is a "prod" cluster:
- the BigQuery dataset will NOT be deleted on `terraform destroy`
- the GKE cluster will NOT be deleted on `terraform destroy`

[`gke-project`]: /infra/gcp/clusters/modules/gke-project
[`gke-nodepool`]: /infra/gcp/clusters/modules/gke-nodepool
