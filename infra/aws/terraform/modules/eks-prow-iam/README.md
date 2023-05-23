# EKS Prow Provisioner IAM

This module contains permissions required to create and maintain 
[EKS Prow clusters](https://github.com/kubernetes/k8s.io/tree/main/infra/aws/terraform/prow-build-cluster).

## Roles

* EKSInfraAdmin - assumed for creating, updating, destroying EKS prow cluster with use of Terraform.
* EKSInfraViewer - assumed for planning infrastructure changes with use of Terraform.

## Policies

Actions aggregated in the following policies have been recorded with [iamlive tool](https://github.com/iann0036/iamlive).

* EKSClusterViewer - IAM actions required for running terraform plan.
* EKSClusterApplier - combined with EKSClusterViewer allows for running terraform apply on EKS prow cluster.
* EKSClusterDestroyer - combined with EKSClusterViewer allows for running terraform destroy on EKS prow cluster.

## Permission Boundaries

* EKSResourcesPermissionBoundary - applied on IAM roles provisioned with EKS prow cluster. It's meant to limit the risk of privilige escalation.
