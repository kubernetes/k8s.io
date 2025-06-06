# vSphere and NSX

The VMware Engine instance provides a vSphere cluster with NSX-T.

The terraform manifest in this folder can be used to setup e.g. content libraries, templates, folders, resource pools and other vSphere settings required when running tests.

See [terraform](../docs/terraform.md) for prerequisites.

The first time after creating the VMware Engine Private Cloud we have to reset the solution-user credentials:

```sh
gcloud vmware private-clouds vcenter credentials reset --private-cloud=k8s-gcp-gcve --username=solution-user-01@gve.local --location=us-central1-a
```

The terraform manifests in this folder require following env variables to be set:

```sh
 export TF_VAR_vsphere_user=solution-user-01@gve.local
 export TF_VAR_vsphere_password="$(gcloud vmware private-clouds vcenter credentials describe --private-cloud=k8s-gcp-gcve --username=solution-user-01@gve.local --location=us-central1-a --format='get(password)')"
 export TF_VAR_vsphere_server="$(gcloud vmware private-clouds describe k8s-gcp-gcve --location us-central1-a --format='get(vcenter.fqdn)')"
 export TF_VAR_nsxt_user=admin
 export TF_VAR_nsxt_password="$(gcloud vmware private-clouds nsx credentials describe --private-cloud k8s-gcp-gcve --location us-central1-a --format='get(password)')"
 export TF_VAR_nsxt_server="$(gcloud vmware private-clouds describe k8s-gcp-gcve --location us-central1-a --format='get(nsx.fqdn)')"
```

Note: solution-user-01@gve.local user gets created automatically in a VMware Engine instance;
we are using it to set up vSphere and create a dedicate user for prow CI (with limited permissions).
For more information see [VMware Engine documentation](https://cloud.google.com/vmware-engine/docs/private-clouds/howto-elevate-privilege).

Also, the terraform manifests in this folder require `/etc/hosts` entries for vSphere and NSX
(see the [terraform](../docs/terraform.md)).

Due to missing features in the terraform provider, user and other IAM configuration must be managed with dedicated scripts, the following script needs to be run before terraform apply:

Run a fist script to create the prow-ci-user@gve.local user to be used for prow CI.

```sh
export GOVC_URL="${TF_VAR_vsphere_server}"
export GOVC_USERNAME="${TF_VAR_vsphere_user}"
export GOVC_PASSWORD="${TF_VAR_vsphere_password}"
 export GCVE_PROW_CI_PASSWORD="SomePassword" # Pick a complex password for the prow CI users.
./scripts/ensure-users-groups.sh
```

When ready:

```sh
terraform init
terraform plan # Check diff
terraform apply
```

After terraform apply, run the following script complete user and other IAM configurations:

```sh
export GOVC_URL="${TF_VAR_vsphere_server}"
export GOVC_USERNAME="${TF_VAR_vsphere_user}"
export GOVC_PASSWORD="${TF_VAR_vsphere_password}"
./scripts/ensure-users-permissions.sh
```

After setting up vSphere, it is required to add credentials to the secret manager for consumption from prow.

```sh
gcloud secrets describe k8s-gcp-gcve-ci-url 2>/dev/null || echo "$GOVC_URL" | gcloud secrets create k8s-gcp-gcve-ci-url --data-file=-
gcloud secrets describe k8s-gcp-gcve-ci-username 2>/dev/null || echo "prow-ci-user@gve.local" | gcloud secrets create k8s-gcp-gcve-ci-username --data-file=-
gcloud secrets describe k8s-gcp-gcve-ci-password 2>/dev/null || echo "${GCVE_PROW_CI_PASSWORD}" | gcloud secrets create k8s-gcp-gcve-ci-password --data-file=-
gcloud secrets describe k8s-gcp-gcve-ci-thumbprint 2>/dev/null || echo "$(govc about.cert -json | jq -r '.thumbprintSHA256')" | gcloud secrets create k8s-gcp-gcve-ci-thumbprint --data-file=-
```

At the end following secrets should exist:
* `k8s-gcp-gcve-ci-url` with value set above for `GOVC_URL`
* `k8s-gcp-gcve-ci-username` with value `prow-ci-user@gve.local`
* `k8s-gcp-gcve-ci-password` with value set above for `GCVE_PROW_CI_PASSWORD`
* `k8s-gcp-gcve-ci-thumbprint` with value set from govc


As a final step it is required to setup Boskos resources of type `gcve-vsphere-project` to allow each test run to use a subset of vSphere resources.
See [Boskos](../docs/boskos.md).

# Accessing vSphere and NSX UI.

If required for maintenance reasons, it is possible to access the vSphere UI via [wirequard](../docs/wireguard.md) / [jumphost VM](../maintenance-jumphost/README.md).

After connecting, vSphere UI is available at https://vcsa-427138.d1de5ee9.us-central1.gve.goog.

vSphere credentials are available in the google cloud console, VMware Engine, Private clouds, Detail of the `k8s-gcp-gcve` private cloud, Management Appliances, key details ([link](https://console.cloud.google.com/vmwareengine/privateclouds/us-central1-a/k8s-gcp-gcve/management-appliances?project=broadcom-451918))


IMPORTANT: do not apply changes using the vSphere UI, always use terraform, or when not possible scripts in this folder.

Similar considerations apply for NSX, which is avalable at http://nsx-427314.d1de5ee9.us-central1.gve.goog

# Changing the GCVE CI user's password

When required to rotate the prow-ci-user@gve.local password:

1. Set GOVC credentials as above.
2. Run govc command to update password: `govc sso.user.update -p "${GCVE_PROW_CI_PASSWORD}" prow-ci-user`
3. Update secret `k8s-gcp-gcve-ci-password` in secrets-manager: `echo "${GCVE_PROW_CI_PASSWORD}" | gcloud secrets versions add k8s-gcp-gcve-ci-password --data-file=-`
