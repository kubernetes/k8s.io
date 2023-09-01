# EKS Node Upgrades

EKS provides [Managed Node Groups](https://docs.aws.amazon.com/eks/latest/userguide/update-managed-node-group.html) that are highly effective for rolling out upgrades. However, we encountered an issue where automatic updates fail due to a PodDisruptionBudget set on our Prow Jobs, resulting in a PodEvictionFailure error. To mitigate the risks associated with forcing the upgrade, which could potentially lead to orphaned test resources, we have devised a solution that involves the introduction of a secondary Node Group.

**Problem:** The PodDisruptionBudget set on our Prow Jobs hinders the successful execution of automatic updates in EKS. [If the Pods don't leave the node within 15 minutes](https://docs.aws.amazon.com/eks/latest/userguide/managed-node-update-behavior.html#managed-node-update-upgrade) and there's no force flag, the upgrade phase fails with a PodEvictionFailure error. Our prow jobs can take much longer than 15 minutes, in many cases more that one hour. As a consequence, we cannot perform seamless updates.

**Proposed Solution:** To address this issue, we have decided to establish two EKS node groups: `blue` and `green`. These node groups will operate in an active-passive manner, allowing us to ensure uninterrupted service while facilitating upgrades.

- The `blue` node group will serve as the active group, hosting all of our workloads and applications.
- The `green` node group will be scaled down, serving as the passive group ready to be activated if necessary.

By adopting this solution, we can avoid potential disruptions caused by forcing upgrades while maintaining the integrity of our test resources.

## Upgrade Procedure

**Note: This procedure assumes that we start with the `blue` node group as the active group.**

1. Locate the `terraform.<env>.tfvars` file and make the following changes:
    - Set `node_desired_size_green` to the current number of nodes in the cluster.
    - Set `node_min_size_green` to 1.
    - Set `node_min_size_blue` to 0.
 2. Open the `eks.tf` file and find the code block defining the `build-green` node group.
    - Merge `local.auto_scaling_tags` with the node group tags to ensure proper AWS tag decoration for cluster-autoscaler discovery.
 3. Introduce intended change to node group, e.g. AMI update.
 4. Apply the changes to the cluster and wait for the new nodes to become available.
 5. Open AWS console, find AutoscalingGroup created by `build-blue` node group and remove following tags:
    - "k8s.io/cluster-autoscaler/${CLUSTER_NAME}" = "owned"
    - "k8s.io/cluster-autoscaler/enabled" = true
 5. Once all the nodes in the `green` node group are up and running, cordon the nodes of the `blue` node group to prevent workload scheduling on those nodes.
 6. Evict all nodes of the `blue` node group. Please note that this step may take some time due to the PodDisruptionBudget.
 7. The cluster-autoscaler should automatically clean up the evicted nodes.
 8. Open the `terraform.<env>.tfvars` file again and set `node_desired_size_blue` to 0.
 9. Locate the code block defining the `build-blue` node group in `eks.tf`.
 9. Remove `local.auto_scaling_tags` from `build-blue` node group tag list to hide resources from cluster-autoscaler.
 10. Apply the changes. The `green` node group is now your active node group.
