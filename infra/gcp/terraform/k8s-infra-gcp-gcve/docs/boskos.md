# Boskos

Boskos support resources of type `gcve-vsphere-project` to allow each test run to use a subset of vSphere resources.

Boskos configuration is split in three parts:

- The definition of the resource type in the [boskos-reaper](https://github.com/kubernetes/k8s.io/blob/main/kubernetes/gke-prow-build/prow/boskos-reaper.yaml) Deployment
    - search for e.g. `gcve-vsphere-project`
- A static list of resources in the [boskos-resources-configmap](https://github.com/kubernetes/k8s.io/blob/main/kubernetes/gke-prow-build/prow/boskos-resources-configmap.yaml)
    - As of today we have 40 Boskos resources (from `k8s-infra-e2e-gcp-gcve-project-001` tp `k8s-infra-e2e-gcp-gcve-project-040`)
- Setting up user data for each resource.

The last step requires access to the Boskos instance running in prow.

Once you get access run the following script: 

```sh
BOSKOS_HOST=""
vsphere/scripts/boskos-userdata.sh
```

This script adds user data to each one of the above resources, e.g. for `k8s-infra-e2e-gcp-gcve-project-001` we are going to set following user data linking to some of the objects previously set up in vSphere for prow tests:
- A vSphere folder, e.g. `/Datacenter/vm/prow/k8s-infra-e2e-gcp-gcve-project-001`
- A vSphere resource pool, e.g. `/Datacenter/host/k8s-gcve-cluster/Resources/prow/k8s-infra-e2e-gcp-gcve-project-001`
- An ipPool with 16 addresses, e.g. `192.168.35.0-192.168.35.15`, corresponding gateway, `192.168.32.1` and CIDR subnet mask prefix, e.g. `21`
