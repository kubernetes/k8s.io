# Service Quotas for Boskos Accounts

This directory contains Terraform configs that apply Service Quotas to AWS
accounts used for boskos in EKS Prow build cluster. Currently, these configs
are only applying [CAPA service quotas](../modules/capa/).

## Terraform State

Terraform state for these configs is stored in `eks-e2e-boskos-tfstate` S3
bucket in `eks-e2e-boskos-001` account.

## Prerequisites

Applying these Terraform configs require static credentials for `provisioner`
IAM user in `eks-e2e-boskos-001` account. This IAM user and relevant roles
are managed with [CloudFormation stacks](../../../cloudformation/iam/eks-e2e-boskos/).

## Applying Terraform Configs

Once static credentials (`AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`) are
set you can use regular Terraform commands to apply these configs.

## Adding New Service Quotas

It's recommended to create a new Terraform module for each set of service
quotas similar to what we have for [CAPA](../modules/capa).
