# Terraform

See [README.md](https://github.com/kubernetes/k8s.io/tree/main/infra/gcp/terraform) for a general intro about using terraform in k8s.io.

In order to apply terraform manifests you  must be enabled to use the "broadcom-451918" project, please reach out to [owners](../OWNERS) in case of need.

Quick reference:

Go to the folder of interest
- [maintenance-jumphost](../maintenance-jumphost/README.md)
- [vsphere](../vsphere/README.md)

Note: the terraform script in the top folder is usually managed by test-infra automation (Atlantis); we don't have to run it manually.

You can use terraform from your local workstation or via a docker container provided by test infra. e.g.
(you can check for latest image [here](https://console.cloud.google.com/artifacts/docker/k8s-staging-infra-tools/us/gcr.io/k8s-infra))

```bash
docker run -it --rm -v $(pwd):/workspace --entrypoint=/bin/bash gcr.io/k8s-staging-infra-tools/k8s-infra:v20241217-f8b07a049
```

From your local workstation / from inside the terraform container:

Login to GCP to get an authentication token to use with terraform.

```bash
gcloud auth application-default login
gcloud auth login
gcloud config set project broadcom-451918
```

Ensure all the env variables expected by the terraform manifest you are planning to run are set:
- [vsphere](../vsphere/README.md)

Ensure the right terraform version expected by the terraform manifest you are planning to run is installed (Note: this requires `tfswitch` which is pre-installed in the docker image. In case of version mismatches, terraform will make you know):

```bash
cd infra/gcp/terraform/k8s-infra-gcp-gcve/
tfswitch
```

Additionally, if applying the vsphere terraform manifest, use the following script to generate `/etc/hosts` entries for vSphere and NSX.

```sh
gcloud vmware private-clouds describe k8s-gcp-gcve --location us-central1-a --format='json' | jq -r '.vcenter.internalIp + " " + .vcenter.fqdn +"\n" + .nsx.internalIp + " " + .nsx.fqdn'
```

Add those entries to `/etc/hosts`.

At this point you are ready to start using `terraform init`, `terraform plan`, `terraform apply` etc.

Notes:
- Terraform state is stored in a gcs bucket with name `k8s-infra-tf-gcp-gcve`, with a folder for each one of the terraform scripts managed in the `k8s-infra-gcp-gcve` folder (gcve, gcve-vcenter, maintenance-jumphost).