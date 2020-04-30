# `k8s-infra-gke-cluster` terraform module

This terraform module defines a GKE Cluster for k8s-infra use
- GCP Service Account for nodes
- BigQuery dataset for usage metering
- GKE cluster with some useful defaults
- No nodes are provided, they are expected to come from the `k8s-infra-gke-nodepool` module

Because this is a "test" cluster:
- the BigQuery dataset will be deleted on `terraform destroy`
- the GKE cluster will be deleted on `terraform destroy`

NOTE: due to [hashicorp/terraform#22544] this cannot be templated to handle
both test and prod clusters

[hashicorp/terraform#22544]: https://github.com/hashicorp/terraform/issues/22544
