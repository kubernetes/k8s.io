# Day 2 Operations of updating OS on nodes or bumping the kubernetes version.
This document covers the steps associated with keeping the build cluster up-to-date with OS updates and updating the k8s
version.

---
## Update build cluster's Kubernetes version.

This guide covers the steps to update the build cluster's kubernetes version from one patch version to another, or
across minor versions through a playbook.

This update guide is applicable for HA clusters, and is extensively used to automate and update the nodes with a particular
version of Kubernetes.

The playbook is written to install the kubeadm utility through a package manager post, and then proceeding to perform
the cluster upgrade. Initially, all the master nodes are updated, followed by which the worker nodes are updated.


#### Prerequisites
```
   ansible
   private key of the bastion node.
```

#### Steps to follow:
1. From the k8s-ansible directory, generate the hosts.yml file on which the Kubernetes cluster updates are to be performed.
   In this case, one can use the `hosts.yml` file under `examples/containerd-cluster/hosts.yml` to contain the IP(s)
   of the following nodes - Bastion, Workers and Masters.
```
[bastion]
1.2.3.4
[masters]
10.20.177.51
10.20.177.26
10.20.177.227
[workers]
10.20.177.39
[workers:vars]
ansible_ssh_common_args='-o ProxyCommand="ssh -W %h:%p -i <path-to-public-key> -q root@X" -i <path-to-public-key>'
[masters:vars]
ansible_ssh_common_args='-o ProxyCommand="ssh -W %h:%p -i <path-to-public-key> -q root@X" -i <path-to-public-key>'
```
2. Set the path to the `kubeconfig` of the cluster under `group_vars/all` - under the `kubeconfig_path` variable.
3. Set the Kubernetes versions in the following variables in `group_vars/all` - under the following variables, for example
   ```
   kubernetes_major_minor: "1.32"
   kubernetes_patch: "2"
   ```
3. Once the above are set use the following command to update the nodes -
   `ansible-playbook -i examples/containerd-cluster/hosts.yml update-k8s-version.yml --extra-vars group_vars/all`
4. This will proceed to update the nodes. Post update, the same can be verified by executing the kubectl version - under
   `Server Version` field
```
# kubectl version
Client Version: v1.32.3
Kustomize Version: v5.5.0
Server Version: v1.33.1
```

---
## Update build cluster's nodes with latest Kernel/patches.

This guide covers the steps to update the build cluster's OS/Kernel/packages to the latest available versions based
on their availability through package managers. It is necessary to keep the nodes to have the latest security patches
installed and have the kernel up-to-date.

This update guide is applicable for HA clusters, and is extensively used to automate and perform the rolling updates of
the nodes.

The strategy used in updating the nodes is by performing rolling-updates to the nodes, post confirming that there are no
pods in the `test-pods` namespace that generally contains the prow-job workloads. The playbook has the mechanism to wait
until the namespace is free from running pods, however, there may be a necessity to terminate the boskos-related pods
as these are generally long-running in nature.

#### Prerequisites
```
   ansible
   private key of the bastion node.
```

#### Steps to follow:
1. From the k8s-ansible directory, generate the hosts.yml file on which the OS updates are to be performed.
   In this case, one can use the hosts.yml file under `examples/containerd-cluster/hosts.yml` to contain the IP(s)
   of the following nodes - Bastion, Workers and Masters.
```
[bastion]
1.2.3.4
[masters]
10.20.177.51
10.20.177.26
10.20.177.227
[workers]
10.20.177.39
[workers:vars]
ansible_ssh_common_args='-o ProxyCommand="ssh -W %h:%p -i <path-to-public-key> -q root@X" -i <path-to-public-key>'
[masters:vars]
ansible_ssh_common_args='-o ProxyCommand="ssh -W %h:%p -i <path-to-public-key> -q root@X" -i <path-to-public-key>'
```
2. Set the path to the `kubeconfig` of the cluster under group_vars/all - under the `kubeconfig_path` variable.
3. Once the above are set use the following command to update the nodes -
   `ansible-playbook -i examples/containerd-cluster/hosts.yml update-os-packages.yml --extra-vars group_vars/all`
4. This will proceed to update the nodes, and reboot them serially if necessary.