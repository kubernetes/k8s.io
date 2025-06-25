# Maintenance jumphost

The maintenance jump host is a VM hosting a wireguard instance for secure and convenient access 
to vSphere and NSX from local machines.

Before using wireguard it is required to first setup things both on your local machine and on the GCP side.
see [wireguard](../docs/wireguard.md)

The maintenance jump host VM can be recreated if necessary; however, by doing so the IP address of the VM will change and all the 
local machine config have to be updated accordingly.

To check if maintenance jump host VM is already up and running, look for the `maintenance-jumphost` VM
into the google cloud console, compute engine, VM instances ([link](https://console.cloud.google.com/compute/instances?project=broadcom-451918)).

To provision the Jump host VM.

See [terraform](../docs/terraform.md) for prerequisites.

```sh
terraform init
terraform apply
```

To reprovision the Jump host VM.
NOTE: this will change the VM IP address; all the local machine config have to be updated accordingly.

```sh
terraform taint google_compute_instance.jumphost
terraform apply
```

To teardown the Jump host VM.
NOTE: A replacement VM will have a new IP address; all the local machine config have to be updated accordingly.

```sh
terraform destroy
```