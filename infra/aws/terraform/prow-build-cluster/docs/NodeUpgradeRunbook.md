# EKS Node Upgrades

EKS provides [Managed Node Groups](https://docs.aws.amazon.com/eks/latest/userguide/update-managed-node-group.html) that are highly effective for rolling out upgrades. However, we encountered an issue where automatic updates fail due to a PodDisruptionBudget set on our Prow Jobs, resulting in a PodEvictionFailure error. To mitigate the risks associated with forcing the upgrade, which could potentially lead to orphaned test resources, we have devised a solution that involves the introduction of a secondary Node Group.

**Problem:** The PodDisruptionBudget set on our Prow Jobs hinders the successful execution of automatic updates in EKS. As a consequence, we cannot perform updates seamlessly without encountering the PodEvictionFailure error.

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
    - Set `tags = local.node_group_tags` to ensure proper AWS tag decoration for cluster-autoscaler discovery.
 3. Apply the changes to the cluster and wait for the new nodes to become available.
 4. Once all the nodes in the `green` node group are up and running, cordon the nodes of the `blue` node group to prevent workload scheduling on those nodes.
 5. Evict all nodes of the `blue` node group. Please note that this step may take some time due to the PodDisruptionBudget.
 6. The cluster-autoscaler should automatically clean up the evicted nodes.
 7. Open the `terraform.<env>.tfvars` file again and set `node_desired_size_blue` to 0.
 8. Locate the code block defining the `build-blue` node group in `eks.tf`.
 9. Set `tags = local.tags` to hide resources from cluster-autoscaler.
 10. Apply the changes. The `green` node group is now your active node group.
