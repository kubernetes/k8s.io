# k8s-infra-prow-build-trusted/prow-build-trusted

These terraform resources define a GCP project containing a GKE cluster
intended to serve as a "trusted build cluster" for prow.k8s.io. This is
intended for jobs that need access to more sensitive secrets, such as
github tokens, or service accounts authorized to push to staging buckets
some service accounts defined for use by pods within the cluster.

## Initial setup

### Provisioning

There was some manual work in bringing this up fully:
- expect `terraform apply` to fail initially while trying to create bindings
  for `roles/iam.workloadIdentityUser`, as the identity namespace won't exist
  until the GKE cluster is created; re-run to succeed
- run `ensure_release_projects.sh` and `ensure-staging-storage.sh` to make
  sure the `gcb-builder` account will be able to run jobs for the
  projects referenced within
- deploy resources and secrets to the cluster
```
# from with a cloud-shell
# e.g. gcloud alpha cloud-shell ssh --project=k8s-infra-prow-build-trusted

# get credentials for the cluster
gcloud container clusters get-credentials \
  prow-build-trusted --project=k8s-prow-build-trusted --region=us-central1

# get k8s.io on here, for this example we'll assume everything's pushed to git
git clone git://github.com/kubernetes/k8s.io

# deploy the resources; note boskos-resources.yaml isn't a configmap
cd k8s.io/infra/gcp/clusters/k8s-infra-prow-build-trusted/prow-build-trusted
kubectl apply -f ./resources

# create the service-account secret
gcloud iam service-accounts keys create \
  --project=k8s-infra-prow-build-trusted \
  --iam-account=prow-build-trusted@k8s-infra-prow-build-trusted.iam.gserviceaccount.com \
  tmp.json
kubectl create secret generic -n test-pods service-account \
  --from-file=service-account.json=tmp.json
rm tmp.json
```

### Connecting to prow.k8s.io

There was some manual work to hook this up to prow.k8s.io:
- generate a kubeconfig with credentials that prow.k8s.io will use to access
  the build cluster, and hand it off to prow.k8s.io on-call
```
# from with a cloud-shell
# e.g. gcloud alpha cloud-shell ssh --project=k8s-infra-prow-build-trusted

# get credentials for the cluster
gcloud container clusters get-credentials \
  prow-build-trusted --project=k8s-prow-build-trusted --region=us-central1

# generate a kubeconfig to handoff to prow.k8s.io on-call
# the "name" is what prowjobs will specify in their cluster: field
# to target this cluster
git clone git://github.com/kubernetes/test-infra
cd test-infra/gencred && go build .
/gencred \
  --context gke_k8s-infra-prow-build-trusted_us-central1_prow-build-trusted \
  --name k8s-infra-prow-build-trusted \
  --serviceaccount \
  --output k8s-infra-prow-build-trusted.kubeconfig.yaml
```
- ask prow.k8s.io on-call to give the build cluster's service account the
  following IAM privileges
```
# write build logs/artifacts to kubernetes-jenkins
gsutil iam ch \
  serviceAccount:prow-build-trusted@k8s-infra-prow-build-trusted.iam.gserviceaccount.com:objectAdmin \
  gs://kubernetes-jenkins
# stage builds for use by other jobs
gsutil iam ch \
  serviceAccount:prow-build-trusted@k8s-infra-prow-build-trusted.iam.gserviceaccount.com:objectAdmin \
  gs://kubernetes-release-pull
```
