## Access the EKS cluster nodes

> [!NOTE]
> The bastion host and SSH keys have been removed in favor of [AWS Systems Manager (Fleet Manager)](https://docs.aws.amazon.com/systems-manager/latest/userguide/what-is-systems-manager.html).

To access the EKS cluster nodes, you need to login to the appropriate AWS account, go to
Systems Manager, and then choose Fleet Manager from the left-hand side menu. Additionally,
make sure that you selected the correct region, which is us-east-2 for the EKS Prow build
cluster.

In the table, find the node that you want to access, then select it by clicking on the
checkbox. To access the node, click on `Node actions`, then `Connect`, and finally on
`Start terminal session`. For more information, see
[the official AWS documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/connect-with-systems-manager-session-manager.html).

This will open a console to the Bottlerocket control container. This container is used
to control the Bottlerocket instance, but it has very limited options and you don't get
to see the instance's filesystem (you only see the filesystem of the said container).
To access the instance fully, run `enable-admin-container`. This will start an admin
container and exec you into it. This container allows you to preview different instance
settings including the instance filesystem, but you cannot mutate the instance. If you need
to change anything, you need to drop in to the instance itself by running `sudo sheltie`.

> [!CAUTION]
> All changes to the instance should be conducted only via Karpenter and user-data, in other words
> manual changes to the instance are considered as the very last resort.
