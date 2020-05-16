# k8s-infra-prow-build/prow-build

These terraform resources define a GCP project containing a GKE cluster
intended to serve as a "build cluster" for prow.k8s.io. There are also
some service accounts defined for use by pods within the cluster.

## Initial Setup

### Provisioning

There was some manual work in bringing this up fully:
- expect `terraform apply` to fail initially while trying to create bindings
  for `roles/iam.workloadIdentityUser`, as the identity namespace won't exist
  until the GKE cluster is created; re-run to succeed
- run `ensure_e2e_projects.sh` to ensure e2e projects have been provisioned,
  and an external ip has been created for boskos-metrics
  - edit `resources/boskos-resources.yaml` to include the projects
  - edit `resources/boskos.yaml` to have `boskos-metrics` use the external ip
- deploy resources to the cluster
```
# from with a cloud-shell
# e.g. gcloud alpha cloud-shell ssh --project=k8s-infra-prow-build

# get credentials for the cluster
gcloud container clusters get-credentials \
  prow-build --project=k8s-prow-build --region=us-central1

# get k8s.io on here, for this example we'll assume everything's pushed to git
git clone git://github.com/kubernetes/k8s.io

# deploy the resources; note boskos-resources.yaml isn't a configmap
cd k8s.io/infra/gcp/clusters/k8s-infra-prow-build/prow-build
kubectl apply -f ./resources
kubectl create configmap -n test-pods resources \
  --from-file=config=./resources/boskos-resources.yaml \
  --dry-run -o=yaml | k replace -f -

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
```
# from with a cloud-shell
# e.g. gcloud alpha cloud-shell ssh --project=k8s-infra-prow-build

# get credentials for the cluster
gcloud container clusters get-credentials \
  prow-build --project=k8s-prow-build --region=us-central1

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
```
# write build logs/artifacts to kubernetes-jenkins
gsutil iam ch \
  serviceAccount:prow-build@k8s-infra-prow-build.iam.gserviceaccount.com:objectAdmin \
  gs://kubernetes-jenkins
# stage builds for use by other jobs
gsutil iam ch \
  serviceAccount:prow-build@k8s-infra-prow-build.iam.gserviceaccount.com:objectAdmin \
  gs://kubernetes-release-pull
# TODO: this isn't working, the bucket is in google-containers project which has
#       a ban on non-google.com accounts being added to iam
gsutil iam ch \
  serviceAccount:prow-build@k8s-infra-prow-build.iam.gserviceaccount.com:objectAdmin \
  gs://kubernetes-release-dev
```

## TODO

- some jobs can't be migrated until we use a bucket other than gs://kubernetes-release-dev
- create a nodepool for greenhouse and deploy to this cluster
- setup postsubmit to deploy boskos-resources.yaml
- decide the story for deploying/upgrading boskos
