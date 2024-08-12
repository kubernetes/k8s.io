# EKS Kubernetes Version Upgrade

## Control Plane Upgrade

To upgrade the Kubernetes version, you need to update the `cluster_version` variable on the cluster's `terraform.tfvars` file:

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

If you need to upgrade already provisioned nodes immediately, you should manually drain the node(s), Karpenter will automatically remove the node due to emptiness. Here is an example:

Get our Karpenter managed node list:
```bash
$> kubectl get nodes -l karpenter.sh/nodepool=default
NAME                                        STATUS   ROLES    AGE     VERSION
ip-10-0-125-19.us-east-2.compute.internal   Ready    <none>   4h12m   v1.29.5-eks-1109419
ip-10-0-164-0.us-east-2.compute.internal    Ready    <none>   4h12m   v1.29.5-eks-1109419
ip-10-0-4-161.us-east-2.compute.internal    Ready    <none>   4h13m   v1.29.5-eks-1109419
ip-10-0-53-105.us-east-2.compute.internal   Ready    <none>   4h13m   v1.29.5-eks-1109419
```

Drain one of the nodes:

```bash
$> kubectl drain ip-10-0-53-105.us-east-2.compute.internal --ignore-daemonsets --delete-emptydir-data
node/ip-10-0-53-105.us-east-2.compute.internal cordoned
...
pod/coredns-7987595ff5-2t224 evicted
node/ip-10-0-53-105.us-east-2.compute.internal drained
```

You will see in the `kubectl get nodes` output that the node is deleted within a minute. You can check the logs:

```bash
$> kubectl logs -l app.kubernetes.io/name=karpenter -n kube-system
...
{"level":"INFO","time":"2024-08-12T11:03:35.323Z","logger":"controller","message":"disrupting via emptiness delete, terminating 1 nodes (0 pods) ip-10-0-53-105.us-east-2.compute.internal/r5ad.xlarge/on-demand","commit":"490ef94","controller":"disruption","command-id":"704b9a1b-3c27-4bca-913e-a79cacc8d0bd"}
{"level":"INFO","time":"2024-08-12T11:03:36.131Z","logger":"controller","message":"command succeeded","commit":"490ef94","controller":"disruption.queue","command-id":"704b9a1b-3c27-4bca-913e-a79cacc8d0bd"}
{"level":"INFO","time":"2024-08-12T11:03:36.172Z","logger":"controller","message":"tainted node","commit":"490ef94","controller":"node.termination","controllerGroup":"","controllerKind":"Node","Node":{"name":"ip-10-0-53-105.us-east-2.compute.internal"},"namespace":"","name":"ip-10-0-53-105.us-east-2.compute.internal","reconcileID":"503a0908-5d66-4477-b8aa-f502c50ae19a"}
{"level":"INFO","time":"2024-08-12T11:03:37.724Z","logger":"controller","message":"deleted node","commit":"490ef94","controller":"node.termination","controllerGroup":"","controllerKind":"Node","Node":{"name":"ip-10-0-53-105.us-east-2.compute.internal"},"namespace":"","name":"ip-10-0-53-105.us-east-2.compute.internal","reconcileID":"12841033-3566-4507-84ca-f3a50b6fe7f8"}
{"level":"INFO","time":"2024-08-12T11:03:38.126Z","logger":"controller","message":"deleted nodeclaim","commit":"490ef94","controller":"nodeclaim.termination","controllerGroup":"karpenter.sh","controllerKind":"NodeClaim","NodeClaim":{"name":"default-jsh9r"},"namespace":"","name":"default-jsh9r","reconcileID":"4ed9cd00-7022-40d1-8dc1-02238d05b11f","Node":{"name":"ip-10-0-53-105.us-east-2.compute.internal"},"provider-id":"aws:///us-east-2a/i-0ec90db31ac978cde"}
```

### Managed Node Groups

EKS provides [Managed Node Groups](https://docs.aws.amazon.com/eks/latest/userguide/update-managed-node-group.html) that are highly effective for rolling out upgrades. It is also recommended to run Karpenter pods on the nodes that are not managed by Karpenter.

There is such node group called `managed-stable` on the cluster. In order to upgrade it's version, you need to update the `node_group_version_stable` variable on the cluster's `terraform.tfvars` file.

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
