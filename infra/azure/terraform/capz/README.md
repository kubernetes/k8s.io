# Getting Started Guide for CAPZ resource management

# azure/terraform/capz
The CAPZ folder structure looks like this:
main.tf
├── resource_group
├── identities
├── key_vault
├── container_registry
├── storage_account
├── role_assignments
├── variables

# Prerequiste 
The `az-cli-prow` service principal with federated credentials must be created by a tenant admin. The [iam-config/gce-param.json](./iam-config/gce-param.json) and [iam-config/eks-param.json](./iam-config/eks-param.json) files can be used for creating the federated credentials for GCE and EKS. Below is an example of how to add a federated credential.

    ```sh
    az ad sp create-for-rbac --name az-cli-prow
    appid=$(az ad sp list --filter "displayName eq 'az-cli-prow'" --query [0].appId --output tsv)
    az ad app federated-credential create --id $appid --parameters param.json 
    ```

The service principal needs the below mentioned role assignments, which gets taken care of by [role-assignments/main.tf](.role-assignments/main.tf): 
- Contributor role access to the sub. 
- Creation of a custom role to give write access
- acrpush role for the registry 
- Storage Blob Data Contributor role for Storage account

Note: To assign Contributor access, the person running this script needs to be a contributor on the Azure subscription. If you are not, reach out to someone who is and ask them to manually run the below command and comment out that bit of code from [role-assignments/main.tf](.role-assignments/main.tf).

    ```sh
    objectid=$(az ad sp list --filter "displayName eq 'az-cli-prow'" --query [0].id --output tsv)
    az role assignment create --assignee-object-id $(objectid) --assignee-principal-type ServicePrincipal --role Contributor --scope /subscriptions/<subid>
    ```

# Terraform State Management

We use an Azure backend to maintain the Terraform state and enable collaboration on the infrastructure resources created.
We use the following values to store and manage the state:

- **Resource Group Name:** `terraform-states-azure`
- **Storage Account Name:** `terraformstatescomm`
- **Container Name:** `tfstate`
- **Key:** `terraform.tfstate`

## To Apply Terraform

Note: The first ever run will take a bit (about 20 minutes) to register the Container Service and Kubernetes Configuration providers while running `main.tf`. Get up and stretch your legs while it wires everything up. The next reapplications of terraform scripts will be a lot faster as terraform does not re-register providers. 

1. Initialize Terraform:
    ```bash
    terraform init
    ```

2. Plan the Terraform deployment and output it to a file:
    ```bash
    terraform plan -out main.tfplan
    ```

3. Apply the planned Terraform deployment:
    ```bash
    terraform apply ./main.tfplan
    ```
