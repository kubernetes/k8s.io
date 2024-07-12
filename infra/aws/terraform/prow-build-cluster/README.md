# EKS-based Prow build cluster

This folder primarily contains Terraform scripts, configurations, and modules necessary
for provisioning and bootstrapping an EKS-based Prow build cluster. Additionally, the `resources`
directory holds Kubernetes resources that are synchronized with the Prow Build Cluster through
a GitOps solution called [FluxCD](https://fluxcd.io/).

## Environments

There are two distinct EKS clusters representing different environments:

* Production Cluster (k8s-infra-prow AWS account): This cluster serves as the build cluster and is connected
  to the Prow control plane on GCP (Google Cloud Platform).
* Canary Cluster (k8s-infra-prow-canary AWS account): This cluster is utilized to validate infrastructure changes before
  implementing them in the production cluster. It is important to note that 
  **the Canary cluster is not connected to the Prow control plane on GCP**.

### Differences between Production and Canary

* AWS Account
* Cluster Name
* Instance Type & Autoscaling Parameters (for some savings)
* Canary is missing k8s-prow OIDC Provider and the corresponding IAM Role

## Tool Requirements

If you are an administrator, it's recommended for you to install following tools:
* [terraform](https://developer.hashicorp.com/terraform/downloads)
* [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl)
* [make](https://www.gnu.org/software/make/)
* [aws cli](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
* [flux cli](https://fluxcd.io/flux/installation/#install-the-flux-cli)

## Provisioninig and Updating Clusters

The instructions on how to provision and make changes to the cloud infrastructure supporting the EKS Prow Build Clusters
can be found in [the IaC document](./docs/IaC.md).

## Interacting with Clusters

If you need to introduce new Kubernetes resources or make modifications to existing ones,
please refer to the instructions provided in [the GitOps document](./docs/GitOps.md).

**Direct interactions with the clusters are intended for cluster administrators only.**
It requires access to the AWS accounts where the clusters are hosted.
As an administrator, your primary tools for interacting with the clusters are `kubectl` and `terraform`.
For `kubectl`, you will need the kubeconfig file, which can be obtained using the AWS cli.

* Production:
    ```bash
    aws eks update-kubeconfig --region us-east-2 --name prow-build-cluster
    ```

* Canary:
    ```bash
    aws eks update-kubeconfig --region us-east-2 --name prow-canary-cluster
    ```

This is going to update your local `~/.kube/config` (unless specified otherwise).
Once you fetched kubeconfig, you need to update it to add assume role arguments,
otherwise you'll have no access to the cluster (e.g. you'll get Unauthorized error).

Open kubeconfig in a text editor of your choice and update `args` for the
appropriate cluster:

* Production:
    ```yaml
    args:
      - --region
      - us-east-2
      - eks
      - get-token
      - --cluster-name
      - prow-build-cluster
      - --role-arn
      - arn:aws:iam::468814281478:role/EKSInfraAdmin
    ```
* Canary:
    ```yaml
    args:
      - --region
      - us-east-2
      - eks
      - get-token
      - --cluster-name
      - prow-canary-cluster
      - --role-arn
      - arn:aws:iam::054318140392:role/EKSInfraAdmin
    ```

## Known Issues

### Cluster Autoscaler "Failed to fix node group sizes" Error

From time to time, the cluster-autoscaler is stuck with the below error and does not scale up/down the cluster:

```
I0712 04:19:50.032692       1 static_autoscaler.go:287] Starting main loop
...
I0712 04:19:50.038343       1 static_autoscaler.go:709] Decreasing size of eks-build-us-east-2c-20240124170707924300000010-92c69e38-4c41-bf62-6938-f48d5fd21243, expected=11 current=10 delta=-1
E0712 04:19:50.038370       1 static_autoscaler.go:439] Failed to fix node group sizes: failed to decrease eks-build-us-east-2c-20240124170707924300000010-92c69e38-4c41-bf62-6938-f48d5fd21243: attempt to delete existing nodes targetSize:11 delta:-1 existingNodes: 11
I0712 04:19:56.488422       1 reflector.go:790] k8s.io/autoscaler/cluster-autoscaler/utils/kubernetes/listers.go:172: Watch close - *v1.Pod total 144 items received
```

That is a known issue when an EC2 instance is created on the node group but cannot join the cluster. You can check the node group sizes on the [AWS Console](https://us-east-2.console.aws.amazon.com/eks/home?region=us-east-2#/clusters/prow-build-cluster?selectedTab=cluster-compute-tab):

![image](https://github.com/user-attachments/assets/ea55cf93-19ee-4e91-bfe3-5a1c84da3778)

or from the aws CLI like so

```bash
aws autoscaling describe-auto-scaling-groups --query 'AutoScalingGroups[].[AutoScalingGroupName, DesiredCapacity]' --output table
```

then compare it with the number of nodes on the cluster:

```bash
kubectl get nodes --show-labels | grep -o 'eks.amazonaws.com/nodegroup=build-us-east-2[abc]' | sort | uniq -c
  19 eks.amazonaws.com/nodegroup=build-us-east-2a
  13 eks.amazonaws.com/nodegroup=build-us-east-2b
  10 eks.amazonaws.com/nodegroup=build-us-east-2c
```

The above output indicates that 11 EC2 instances exist on the `build-us-east-2c` node group, but 10 of them are part of the cluster.

The hanging node must be found and manually deleted from the EC2 console.
