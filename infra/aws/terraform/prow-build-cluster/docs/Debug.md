## SSH Access EKS Nodes

To access cluster nodes via ssh, first you need to provision bastion host:

```bash
TF_ARGS="-var bastion_install=true" make apply
```

After successful apply, terraform outputs should get updated with ip address of the bastion host.
Use following snippet for accessing cluster node:

```bash
# Access to private key is limited to cluster administrators.
ssh-add <path_to_private_key>

# Example node name copied from the result of `kubectl get nodes`.
export TARGET_NODE='ip-10-1-64-11.us-east-2.compute.internal'

export BASTION_IP=$(make output | jq '.bastion_ip_address.value' | tr -d '"')

ssh -A -J ubuntu@${BASTION_IP} ubuntu@${TARGET_NODE}
```

**Remember to remove the bastion host after debugging.**

```
make apply
```
