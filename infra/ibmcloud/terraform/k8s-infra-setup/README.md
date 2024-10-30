# _TF: IBM K8s Account Infrastructure_
This Terraform configuration sets up an organized structure for deploying various IBM Cloud resources using modules. 

---
# To run the automation, follow these steps in order:

**1. Navigate to the correct directory**
<br> You need to be in the `k8s-infra-setup` directory to run the automation.

**2. Check the `versions.tf` file**
<br> Set `secret_key` and `access_key` in `versions.tf` to configure the remote S3 backend (IBM Cloud COS).

**3. Initialize Terraform**
<br> Execute the following command to initialize Terraform in your project directory. This command will download the necessary provider plugins and prepare the working environment.
```
terraform init -reconfigure
```

**4. Check the `variables.tf` file**
<br> Open the `variables.tf` file to review all the available variables. This file lists all customizable inputs for your Terraform configuration.

`ibmcloud_api_key` is the only required variable that you must set in order to proceed. You can set this key either by adding it to your `var.tfvars` file or by exporting it as an environment variable.

**Option 1:** Set in `var.tfvars` file
Add the following line to the `var.tfvars` file:
```
ibmcloud_api_key = "<YOUR_API_KEY>"
```

**Option 2:** Export as an environment variable
Alternatively, you can export the ibmcloud_api_key as an environment variable before running Terraform:
```
export TF_VAR_ibmcloud_api_key="<YOUR_API_KEY>"
```

**5. Run Terraform Apply**
<br> After setting the necessary variables (particularly the API_KEY), execute the following command to apply the Terraform configuration and provision the infrastructure:
```
terraform apply -var-file var.tfvars
```
Terraform will display a plan of the actions it will take, and you'll be prompted to confirm the execution. Type `yes` to proceed.

**6 .Get Output Information**
<br> Once the infrastructure has been provisioned, use the terraform output command to list details about the provisioned resources.
```
terraform output
```
