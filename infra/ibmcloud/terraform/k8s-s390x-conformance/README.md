# _TF: IBM K8s s390x Conformance_
These define Terraform resources for setting up infrastructure for the Kubernetes on s390x conformance job.

---
## Initial Setup

### Supporting infrastructure

#### Deploy k8s-infra-setup resources

- this covers things like Resource Group, s390x Virtual Server Workspace, Virtual Private Cloud, IBM Cloud Secret Manager Secrets, Transit Gateway, etc.
- Once the deployment successfully completes, the `service_instance_id` and `secrets_manager_id` will be generated and should be used in the subsequent steps.

---
#### Deploy k8s-s390x-conformance resources

**1. Navigate to the correct directory**
<br> You need to be in the `k8s-s390x-conformance` directory to run the automation.

**2. Check the `versions.tf` file**
<br> Set `secret_key` and `access_key` in `versions.tf` to configure the remote S3 backend (IBM Cloud COS).

**3. Initialize Terraform**
<br> Execute the following command to initialize Terraform in your project directory. This command will download the necessary provider plugins and prepare the working environment.
```
terraform init -reconfigure
```

**4. Check the `variables.tf` file**
<br> Open the `variables.tf` file to review all the available variables. This file lists all customizable inputs for your Terraform configuration.

`ibmcloud_api_key`, `service_instance_id`, `secrets_manager_id` are the only required variables that you must set in order to proceed. You can set this key either by adding it to your `var.tfvars` file or by exporting it as an environment variable.

**Option 1:** Set in `var.tfvars` file
Create `var.tfvars` file and set the following variables in `var.tfvars` file:
```
ibmcloud_api_key    = "<YOUR_API_KEY>"
secrets_manager_id  = "<SECRETS_MANAGER_ID>"
```

**Option 2:** Export as an environment variable
Alternatively, you can export above as an environment variable before running Terraform:
```
export TF_VAR_ibmcloud_api_key="<YOUR_API_KEY>"
export TF_VAR_secrets_manager_id="<SECRETS_MANAGER_ID>"
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
