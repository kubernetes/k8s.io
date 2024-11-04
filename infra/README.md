# IP Assignments

This file is being stored temporarily here to track RFC 1918 IP space allocation to avoid network IP conflicts.
It is important that our infrastructure across all vendors can be connected to each other.

## IP Allocations

Azure:

- 10.152.0.0/16 k8s-infra-aks-prow-build

AWS:

- 10.128.0.0/16 k8s-infra-kops-prow-build
- 10.0.0.0/16 eks-prow-build-cluster

GCP:

- 10.250.0.0/16 for k8s-infra-prow GCP project

Oracle:

VMWare SDDC: TBD

## Clusters that must be rebuilt and moved to a new network

- k8s-infra-prow-build
- k8s-infra-prow-build-trusted
