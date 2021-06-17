# k8s-infra-prow-build/prow-build

These terraform resources define a GCP project containing a GKE cluster
intended to serve as a "build cluster" for prow.k8s.io. There are also
some service accounts defined for use by pods within the cluster.

## Access

Access to the [k8s-infra-prow-build project][k8s-infra-prow-build-console] hosting the cluster is granted by membership in one of two @kubernetes.io groups:
- [k8s-infra-prow-oncall@kubernetes.io][k8s-infra-prow-oncall@]: grants [`roles/owner`][roles/owner] access
- [k8s-infra-prow-viewers@kubernetes.io][k8s-infra-prow-viewers@]: grants [`prow.viewer`][roles/prow.viewer] access

If you are not a member of either of these groups, please [follow these instructions to join][join-groups]

```shell
# Login to set the authenticated user for gcloud
gcloud auth login

# Get kubeconfig credentials for the cluster
gcloud container clusters get-credentials \
  prow-build --project=k8s-infra-prow-build --region=us-central1

# Now you can use kubectl...
```

## Initial Setup

### Provisioning

There was some manual work in bringing this up fully:
- expect `terraform apply` to fail initially while trying to create bindings
  for `roles/iam.workloadIdentityUser`, as the identity namespace won't exist
  until the GKE cluster is created; re-run to succeed
- edit `resources/boskos.yaml` to have `boskos-metrics` use the external ip
  provisioned by terraform
- run `ensure_e2e_projects.sh` to ensure e2e projects have been provisioned
  - edit `resources/boskos-resources.yaml` to include the projects
- deploy resources to the cluster
```shell
# First get access to the cluster control plane by following the instructions
# in the section above.

# get k8s.io on here, for this example we'll assume everything's pushed to git
git clone git://github.com/kubernetes/k8s.io

# deploy the resources; note boskos-resources.yaml isn't a configmap
cd k8s.io/infra/gcp/clusters/k8s-infra-prow-build
./deploy.sh

# create the service-account secret
gcloud iam service-accounts keys create \
  --project=k8s-infra-prow-build \
  --iam-account=prow-build@k8s-infra-prow-build.iam.gserviceaccount.com \
  tmp.json
kubectl create secret generic -n test-pods service-account \
  --from-file=service-account.json=tmp.json
rm tmp.json

# create the ssh-key-secret
# TODO: these files were manually created and the pubkey hardcoded into
#       ensure_e2e_projects.sh above; consider rewriting this guide to
#       describe generating the key, and then store it into cloud secrets
#       to get it here
kubectl create secret generic -n test-pods ssh-key-secret \
  --from-file=ssh-private=prow-build-test.ssh-key \
  --from-file=ssh-public=prow-build-test.ssh-key.pub
rm prow-build-test.ssh-key*
```

### Connecting to prow.k8s.io

There was some manual work to hook this up to prow.k8s.io:
- generate a kubeconfig with credentials that prow.k8s.io will use to access
  the build cluster, and hand it off to prow.k8s.io on-call
```shell
# First get access to the cluster control plane by following the instructions
# in the section above.

# generate a kubeconfig to handoff to prow.k8s.io on-call
# the "name" is what prowjobs will specify in their cluster: field
# to target this cluster
git clone git://github.com/kubernetes/test-infra
cd test-infra/gencred && go build .
/gencred \
  --context gke_k8s-infra-prow-build_us-central1_prow-build \
  --name k8s-infra-prow-build \
  --serviceaccount \
  --output k8s-infra-prow-build.kubeconfig.yaml
```
- ask prow.k8s.io on-call to give the build cluster's service account the
  following IAM privileges
```shell
# write build logs/artifacts to kubernetes-jenkins
gsutil iam ch \
  serviceAccount:prow-build@k8s-infra-prow-build.iam.gserviceaccount.com:objectAdmin \
  gs://kubernetes-jenkins
# stage builds for use by other jobs
gsutil iam ch \
  serviceAccount:prow-build@k8s-infra-prow-build.iam.gserviceaccount.com:objectAdmin \
  gs://kubernetes-release-pull
```

## Ongoing Maintenance

### prow-build cluster

#### Deploy cluster resources

- resources are deployed by [post-k8sio-deploy-prow-build-resources] when PRs
  merge
- the job runs [deploy.sh] to deploy resources; if neccessary, users with
  [sufficient privileges](#access) can run this script to do the same thing

#### Deploy cluster changes

- open a PR with the proposed changes
- run `tfswitch` to ensure the correct version of terraform is installed
- run `terraform init` to ensure the correct version of modules/providers
  are installed
- run `terraform plan` to verify what changes will be deployed; if there are
  unexpected deletions or changes, ask for help in [#wg-k8s-infra]
- run `terraform apply` to deploy the changes

#### Upgrade cluster version

- upgrades are handled automatically by GKE during a scheduled maintenance window

### Supporting infrastructure

#### Deploy k8s-infra-prow-build GCP resource changes

- this covers things like Service Accounts, GCS Buckets, APIs / Services,
  Google Secret Manager Secrets, etc.
- add resources to `main.tf`, then follow the same steps as [Deploy cluster changes]

#### Deploy e2e project changes

- run [`ensure-e2e-projects.sh`][ensure-e2e-projects.sh]

## Known Issues / TODO

- some jobs can't be migrated until we use a bucket other than gs://kubernetes-release-dev
- setup an autobump jump for all components installed to this build cluster
- try using local SSD for the node pools for faster IOPS

[k8s-infra-prow-build-console]: https://console.cloud.google.com/home/dashboard?project=k8s-infra-prow-build
[k8s-infra-prow-oncall]: https://github.com/kubernetes/k8s.io/blob/3a1aea1652f02a95253402bde2bca63cb4292f8e/groups/groups.yaml#L647-L670
[k8s-infra-prow-viewers]: https://github.com/kubernetes/k8s.io/blob/3a1aea1652f02a95253402bde2bca63cb4292f8e/groups/groups.yaml#L672-L699
[roles/owner]: https://cloud.google.com/iam/docs/understanding-roles#basic-definitions
[roles/prow.viewer]: https://github.com/kubernetes/k8s.io/blob/main/infra/gcp/roles/prow.viewer.yaml
[join-groups]: https://github.com/kubernetes/k8s.io/tree/main/groups#making-changes
[post-k8sio-deploy-prow-build-resources]: https://testgrid.k8s.io/wg-k8s-infra-k8sio#post-k8sio-deploy-prow-build-resources
[deploy.sh]: /infra/gcp/clusters/k8s-infra-prow-build/deploy.sh
[ensure-e2e-projects.sh]: /infra/gcp/prow/ensure-e2e-projects.sh
[#wg-k8s-infra]: https://kubernetes.slack.com/messages/wg-k8s-infra