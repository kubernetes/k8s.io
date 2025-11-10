# _TF: IBM K8s s390x Build Cluster_
These terraform resources define a IBM Cloud project containing a s390xVS cluster intended to serve as a "build cluster" for prow.k8s.io.

---
## Initial Setup

### Supporting infrastructure

#### Deploy k8s-infra-setup resources

- this covers things like Resource Group, s390x Virtual Server Instances, Virtual Private Cloud, IBM Cloud Secret Manager Secrets, etc.
- Once the deployment successfully completes, the `secrets_manager_id` will be generated and should be used in the subsequent steps.

---
#### Deploy k8s-s390x-build-cluster resources

**1. Navigate to the correct directory**
<br> You need to be in the `k8s-s390x-build-cluster` directory to run the automation.

**2. Export COS Secrets**
<br> Export `access_key` and `secret_key` as environment variables.
```
export AWS_ACCESS_KEY_ID="<HMAC_ACCESS_KEY_ID>"
export AWS_SECRET_ACCESS_KEY="<HMAC_SECRET_ACCESS_KEY>"
```

**3. Initialize Terraform**
<br> Execute the following command to initialize Terraform in your project directory. This command will download the necessary provider plugins and prepare the working environment.
```
terraform init -reconfigure
```

**4. Check the `variables.tf` file**
<br> Open the `variables.tf` file to review all the available variables. This file lists all customizable inputs for your Terraform configuration.

`ibmcloud_api_key`, `secrets_manager_id` are the only required variables that you must set in order to proceed. You can set this key either by adding it to your `var.tfvars` file or by exporting it as an environment variable.

**Option 1:** Set in `var.tfvars` file
Create `var.tfvars` file and set the following variables in `var.tfvars` file:
```
ibmcloud_api_key    = "<YOUR_API_KEY>"
secrets_manager_id  = "<SECRETS_MANAGER_ID>"
```
Tip: To get the secrets_manager_id (GUID) for IBM Cloud Secrets Manager instance:
```
ibmcloud resource service-instances --service-name secrets-manager --output JSON | \
jq -r '.[] | select(.name | contains("k8s-s390x")) | .guid'
```
**Option 2:** Export as an environment variable
Alternatively, you can export above as an environment variable before running Terraform:
```
export TF_VAR_ibmcloud_api_key="<YOUR_API_KEY>"
export TF_VAR_secrets_manager_id=$(ibmcloud resource service-instances --service-name secrets-manager --output JSON | \
jq -r '.[] | select(.name | contains("k8s-s390x")) | .guid')
```

**5. Run Terraform Apply**
<br> After setting the necessary variables (particularly the API_KEY), execute the following command to apply the Terraform configuration and provision the infrastructure:
```
terraform apply -var-file var.tfvars
```
Terraform will display a plan of the actions it will take, and you'll be prompted to confirm the execution. Type `yes` to proceed.

**6. Get Output Information**
<br> Once the infrastructure has been provisioned, use the terraform output command to list details about the provisioned resources.
```
terraform output
```

**7. Set up the Kubernetes cluster using ansible**
Clone the repository `https://github.com/kubernetes-sigs/provider-ibmcloud-test-infra` and change the directory to `kubetest2-tf/data/k8s-ansible`:
```
cd kubetest2-tf/data/k8s-ansible
```

**8. Install ansible on the deployer VM**
```
dnf install ansible -y
```

**9. Update the fields under `group_vars/all` to include the Kubernetes version to install**
<br> The following lines will update the version to the latest stable release of Kubernetes. You can modify it accordingly to set up the CI (alpha) version.
```
K8S_VERSION=$(curl -Ls https://dl.k8s.io/release/stable.txt)
LOADBALANCER_EP=<mention the loadbalancer endpoint obtained from terraform output>
sed -i \
-e "s/^directory: .*/directory: release/" \
-e "s/build_version: .*/build_version: $K8S_VERSION/" \
-e "s/release_marker: .*/release_marker: $K8S_VERSION/" \
-e "s/loadbalancer: .*/loadbalancer: $LOADBALANCER_EP/" group_vars/all
```

**10. Update the fields under `examples/k8s-build-cluster/hosts.yml` to contain IP addresses of the VMs to set up Kubernetes**
```
For example:

[bastion]
56.77.34.6

[masters]
192.168.100.3
192.168.100.4

[workers]
192.168.100.5
192.168.100.6
192.168.100.7

[workers:vars]
ansible_ssh_common_args='-o ProxyCommand="ssh -W %h:%p -i <path/to/private-key> -q root@56.77.34.6" -i <path/to/private-key>'

[masters:vars]
ansible_ssh_common_args='-o ProxyCommand="ssh -W %h:%p -i <path/to/private-key> -q root@56.77.34.6" -i <path/to/private-key>'
```

**11. Update the fields under `group_vars/bastion_configuration` to contain the information of the private network.**
```
For example:

bastion_private_gateway: 192.168.100.1
bastion_private_ip: 192.168.100.2
```

**12. Trigger the installation using ansible**
```
ansible-playbook -v -i examples/k8s-build-cluster/hosts.yml install-k8s-ha.yaml -e @group_vars/bastion_configuration --extra-vars @group_vars/all
```
