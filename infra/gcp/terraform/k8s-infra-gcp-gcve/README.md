# Setup

## Creation of GCVE

```sh
gcloud auth application-default login
terraform init
terraform apply
```

## Setup jumphost/vpn for further configuration

See [maintenance-jumphost/README.md](./maintenance-jumphost/README.md).

## Manual creation of a user and other IAM configuration in vSphere

> **Note:**
> The configuration described here cannot be done via terraform due to non-existing functionality.

First we generate a password for the user which will be used in prow and set it as environment variable:

```sh
 export GCVE_PROW_CI_PASSWORD="SomePassword"
```

And set credentials for `govc`:

```sh
 export GOVC_URL="$(gcloud vmware private-clouds describe k8s-gcp-gcve-pc --location us-central1-a --format='get(vcenter.fqdn)')"
 export GOVC_USERNAME='solution-user-01@gve.local'
 export GOVC_PASSWORD="$(gcloud vmware private-clouds vcenter credentials describe --private-cloud=k8s-gcp-gcve-pc --username=solution-user-01@gve.local --location=us-central1-a --format='get(password)')"
```

Run the script to setup the user, groups and IAM in vSphere.

```
./vsphere/scripts/ensure-users-groups.sh
```

Create relevant secrets in Secrets Manager

```sh
gcloud secrets describe k8s-gcp-gcve-ci-url 2>/dev/null || echo "$GOVC_URL" | gcloud secrets create k8s-gcp-gcve-ci-url --data-file=-
gcloud secrets describe k8s-gcp-gcve-ci-username 2>/dev/null || echo "prow-ci-user@gve.local" | gcloud secrets create k8s-gcp-gcve-ci-username --data-file=-
gcloud secrets describe k8s-gcp-gcve-ci-password 2>/dev/null || echo "${GCVE_PROW_CI_PASSWORD}" | gcloud secrets create k8s-gcp-gcve-ci-password --data-file=-
gcloud secrets describe k8s-gcp-gcve-ci-thumbprint 2>/dev/null || echo "$(govc about.cert -json | jq -r '.thumbprintSHA256')" | gcloud secrets create k8s-gcp-gcve-ci-thumbprint --data-file=-
```

* `k8s-gcp-gcve-ci-username` with value `prow-ci-user@gve.local`
* `k8s-gcp-gcve-ci-password` with value set above for `GCVE_PROW_CI_PASSWORD`
* `k8s-gcp-gcve-ci-url` with value set above for `GOVC_URL`

> **Note:** Changing the GCVE CI user's password
>
> 1. Set GOVC credentials as above.
> 2. Run govc command to update password: `govc sso.user.update -p "${GCVE_PROW_CI_PASSWORD}" prow-ci-user`
> 3. Update secret `k8s-gcp-gcve-ci-password` in secrets-manager: `echo "${GCVE_PROW_CI_PASSWORD}" | gcloud secrets versions add k8s-gcp-gcve-ci-password --data-file=-`

## Configuration of GCVE

```sh
 export TF_VAR_vsphere_user=solution-user-01@gve.local
 export TF_VAR_vsphere_password="$(gcloud vmware private-clouds vcenter credentials describe --private-cloud=k8s-gcp-gcve-pc --username=solution-user-01@gve.local --location=us-central1-a --format='get(password)')" # gcloud command
 export TF_VAR_vsphere_server="$(gcloud vmware private-clouds describe k8s-gcp-gcve-pc --location us-central1-a --format='get(vcenter.fqdn)')"
 export TF_VAR_nsxt_user=admin
 export TF_VAR_nsxt_password="$(gcloud vmware private-clouds nsx credentials describe --private-cloud k8s-gcp-gcve-pc --location us-central1-a --format='get(password)')"
 export TF_VAR_nsxt_server="$(gcloud vmware private-clouds describe k8s-gcp-gcve-pc --location us-central1-a --format='get(nsx.fqdn)')"
 export GOVC_URL="${TF_VAR_vsphere_server}"
 export GOVC_USERNAME="${TF_VAR_vsphere_user}"
 export GOVC_PASSWORD="${TF_VAR_vsphere_password}"
```

```sh
cd vsphere
terraform init
terraform apply
./scripts/ensure-users-permissions.sh
```

## Initialize Boskos resources with project information

The script [boskos-userdata.sh](vsphere/scripts/boskos-userdata.sh) calculates and initializes the Boskos resources required for the project.

```sh
BOSKOS_HOST=""
vsphere/scripts/boskos-userdata.sh
```
