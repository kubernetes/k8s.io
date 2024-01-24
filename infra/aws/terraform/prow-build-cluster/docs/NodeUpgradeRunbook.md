# EKS Node Upgrades

EKS provides [Managed Node Groups](https://docs.aws.amazon.com/eks/latest/userguide/update-managed-node-group.html) that are highly effective for rolling out upgrades. However, we encountered an issue where automatic updates fail due to a PodDisruptionBudget set on our Prow Jobs, resulting in a PodEvictionFailure error. To mitigate the risks associated with forcing the upgrade, which could potentially lead to orphaned test resources, we came up with an upgrade notebook that should be used to faciliate upgrades.

**Problem:** The PodDisruptionBudget set on our Prow Jobs hinders the successful execution of automatic updates in EKS. [If the Pods don't leave the node within 15 minutes](https://docs.aws.amazon.com/eks/latest/userguide/managed-node-update-behavior.html#managed-node-update-upgrade) and there's no force flag, the upgrade phase fails with a PodEvictionFailure error. Our prow jobs can take much longer than 15 minutes, in many cases more that one hour. As a consequence, we cannot perform seamless updates.

**Proposed Solution:** To address this issue, we have decided to upgrade only one node group at the time. By adopting this solution, we can avoid potential disruptions caused by forcing upgrades while maintaining the integrity of our test resources.

## Upgrade Procedure

1. Locate the `terraform.<env>.tfvars` file and introduce following changes:
    - Set `node_desired_size_us_east_2a` to the current number of nodes in the node group.
    - Set `node_min_size_us_east_2a` to 1.
    - Set `node_min_size_us_east_2a` to 0.
2. Open the `node_group_us_east_2a.tf` file and find `tags` block.
    - Extend merge function with `local.auto_scaling_tags` to add cluster-autoscaler discovery tags if missing.
3. Apply the changes to the cluster and wait for new nodes to become available.
4. Open AWS console\*, find AutoscalingGroup created by `build-us-east-2a` node group, and remove following tags in order to disable autoscaling:
    - "k8s.io/cluster-autoscaler/${CLUSTER_NAME}" = "owned"
    - "k8s.io/cluster-autoscaler/enabled" = true
5. Cordon all nodes in the `build-us-east-2a` group using kubectl to prevent workload scheduling on those nodes. Wait for running Pods to finish before proceeding.
6. Open the `terraform.<env>.tfvars` file again and set `node_desired_size_us_east_2a` to 0, then apply the change (this might require changing the Autoscaling Group manually via the AWS console). Wait for nodes to be gone before proceeding.
7. Introduce intended change to the node group, e.g. AMI update or Kubernetes version update, then apply the change.
8. Open the `terraform.<env>.tfvars` file again and set `node_desired_size_us_east_2a` to the previous value, then apply the change (this might require changing the Autoscaling Group manually via the AWS console). Wait for nodes to become available before proceeding.
9. Open the `node_group_us_east_2a.tf` file and find `tags` block.
    - Extend merge function with `local.auto_scaling_tags` to add cluster-autoscaler discovery tags if missing.
13. Apply the changes. Repeat these steps for remaining two node groups (`build-us-east-2b` and `build-us-east-2c`)

\* Unfotunately, removing autoscaling tags in terraform script triggers node recreation.
