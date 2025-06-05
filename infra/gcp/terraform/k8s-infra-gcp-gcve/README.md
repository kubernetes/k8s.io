# Overview

The code in `k8s-infra-gcp-gcve` sets up the infra required to allow prow jobs to create VMs on vSphere, e.g. to allow testing  of the [Cluster API provider vSphere (CAPV)](https://github.com/kubernetes-sigs/cluster-api-provider-vsphere).

![Overview](./docs/images/overview.jpg)

Prow container settings are managed outside of this folder, but understanding high level components could
help to understand how the `k8s-infra-gcp-gcve` is set up and consumed.

More specifically, to allow prow jobs to create VM on vSphere, a few resources are made available to a prow container, so as of today only in the `k8s-infra-prow-build` prow cluster.

- A secret, added via the `preset-gcve-e2e-config` [preset](https://github.com/kubernetes/test-infra/blob/master/config/jobs/kubernetes-sigs/cluster-api-provider-vsphere/cluster-api-provider-vsphere-presets.yaml), that provides vSphere URL and vSphere credentials
- A set of Boskos resources of type `gcve-vsphere-project`, allowing access to:
    - a vSphere folder and a vSphere resources pool where to run VMs during a test.
    - a reserved IP range to be used for the test e.g. for the kube vip load balancer in a CAPV cluster (VM instead will get IPs via DHCP).

Also, the network of the prow container is going to be paired to the VMware engine network, thus
allowing access to both the GCVE management network and the NSX-T network where all the VM are running.

The `k8s-infra-gcp-gcve` project sets up the infrastructure that actually runs the VMs created from the prow container. 
These are the main components of this infrastructure:

The terraform manifest in this folder uses the GCP terraform provider for creating.
- A VMware Engine instance
- The network infrastructure required for vSphere and for allowing communication between vSphere and Prow container.
    -  The network used is `192.168.0.32/21`
        - Usable Host IP Range:	`192.168.32.1 - 192.168.39.254`
            - DHCP Range: `192.168.32.11 - 192.168.33.255`
            - IPPool for 40 Projects having 16 IPs each: `192.168.35.0 - 192.168.37.127`
- The network infrastructure used for maintenance.

See [terraform](../docs/terraform.md) for prerequisites.

When ready:

```sh
terraform init
terraform plan # Check diff
terraform apply
```

See inline comments for more details.

The terraform manifest in the `/maintenance-jumphost` uses the GCP terraform provider to setup a jumphost VM to be used to set up vSphere or for maintenance purposes. See
- [maintenance-jumphost](./maintenance-jumphost/README.md)

The terraform manifest in the `/vsphere` folder uses the vSphere and the NSX terraform providers to setup e.g. content libraries, templates, folders, 
resource pools and other vSphere components required when running tests. See:
- [vsphere](./vsphere/README.md)
