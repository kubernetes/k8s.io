# Prow Build Canary Cluster

This directory contains a mirror of scripts used for provisioning EKS prow-build-cluster. It is meant testing infrastructure/configuration changes before applying on production Prow cluster.

Here are some differences compared to the production setup:
* cluster name,
* cluster admin IAM role,
* secrets-manager IAM policy,
* missing `prow.tf` (originally used for configuring prow permissions),
* subnet setup,
* instance type and autoscaling paramethers (mainly for saving),
* cluster contains only basic components without monitoring stack.

## Provisioning Cluster

Running installation from scratch is different than consecutive invocations of Terraform. First run creates a role that can be later assumed by other users. Becasue of that additional variable has to be set:

```bash
terraform init
terraform plan -var="assume_role=false"
terraform apply -var="assume_role=false"
```

Once the infrastructure is provisioned, next step is RBAC setup:

```bash
# fetch & update kubeconfig
aws eks update-kubeconfig --region us-east-2 --name prow-build-canary-cluster

# create cluster role bindings
kubectl apply -f ./resources/rbac
```

Lastly, run Terraform script again without additinal variable. This time, it will implicitly assume previously created role and provision resources on top of EKS cluster.

```bash
terraform apply
```

From here, all consecutive runs should be possible with command from above.

## Removing cluster

Same as for installation, cluster removal requires running Terraform twice. **IMPORTANT**: It's possible only for users with assigned `AdministratorAccess` policy.

```bash
# First remove resources running on the cluster and IAM role. This fails once assumed role gets deleted.
terraform destroy

# Clean up the rest. 
terraform destroy -var="assume_role=false"
```

