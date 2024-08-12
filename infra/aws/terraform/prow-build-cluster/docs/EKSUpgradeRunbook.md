# EKS Kubernetes Version Upgrade

## Control Plane Upgrade

To upgrade the Kubernetes version, you need to update the `cluster_version` variable on the cluster's tfvar files:

```diff
## canary cluster:
#infra/aws/terraform/prow-build-cluster/terraform.canary.tfvars

## prod cluster:
#infra/aws/terraform/prow-build-cluster/terraform.prod.tfvars

--- a/infra/aws/terraform/prow-build-cluster/terraform.canary.tfvars
+++ b/infra/aws/terraform/prow-build-cluster/terraform.canary.tfvars
@@ -31,13 +31,13 @@ eks_cluster_admins = [
 ]
 
 cluster_name               = "prow-canary-cluster"
-cluster_version            = "1.28"
+cluster_version            = "1.29"
```

After this change, you need to run `make plan` and `make apply` commands. (Checkout [IaC Document](./IaC.md) for more information).


## Worker Nodes Upgrade

### Karpenter

The current configuraiotn for Karpenter NodePool uses `amiFamily` setting. As a result, any new nodes provisioned after the cluster upgrade will automatically use the latest AMI for the new Kubernetes version.

If you need to upgrade already provisioned nodes immediately, you should manually cordon, drain, and terminate those nodes to replace them with new nodes running the updated Kubernetes version.

### Managed Node Groups

EKS provides [Managed Node Groups](https://docs.aws.amazon.com/eks/latest/userguide/update-managed-node-group.html) that are highly effective for rolling out upgrades. It is also recommended to run Karpenter pods on the nodes that are not managed by Karpenter.

There is such node group called `managed-stable` on the cluster. In order to upgrade it's version, you need to update the `node_group_version_stable` variable on the cluster's tfvar files.

```diff
--- a/infra/aws/terraform/prow-build-cluster/terraform.canary.tfvars
+++ b/infra/aws/terraform/prow-build-cluster/terraform.canary.tfvars
@@ -31,13 +31,13 @@ eks_cluster_admins = [
 ]
 
 cluster_name               = "prow-canary-cluster"
 ...
-node_group_version_stable     = "1.28"
+node_group_version_stable     = "1.29"
```

After this change, you need to run `make plan` and `make apply` commands.

This will create 3 new nodes with the new version, and cordon the old ones. The old nodes will be removed one by one after they are all drained.
