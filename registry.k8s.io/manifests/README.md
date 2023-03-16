# AR/GCR Manifests

This directory holds the manifest metadata for all of our sub-projects.  These
files define the source and destination repos and paths that the promoter is
allowed to operate on.

These subdirectories MUST NOT have delegated OWNERS files - they represent
sensitive configuration that needs careful review, and should almost never
change.

Reviewers should ensure that:
* The source registry is one that we trust.
* The following destination registries must be specified:
```
us.gcr.io/k8s-artifacts-prod
eu.gcr.io/k8s-artifacts-prod
asia.gcr.io/k8s-artifacts-prod
asia-east1-docker.pkg.dev/k8s-artifacts-prod/images
asia-south1-docker.pkg.dev/k8s-artifacts-prod/images
asia-northeast1-docker.pkg.dev/k8s-artifacts-prod/images
asia-northeast2-docker.pkg.dev/k8s-artifacts-prod/images
australia-southeast1-docker.pkg.dev/k8s-artifacts-prod/images
europe-north1-docker.pkg.dev/k8s-artifacts-prod/images
europe-southwest1-docker.pkg.dev/k8s-artifacts-prod/images
europe-west1-docker.pkg.dev/k8s-artifacts-prod/images
europe-west2-docker.pkg.dev/k8s-artifacts-prod/images
europe-west4-docker.pkg.dev/k8s-artifacts-prod/images
europe-west8-docker.pkg.dev/k8s-artifacts-prod/images
europe-west9-docker.pkg.dev/k8s-artifacts-prod/images
southamerica-west1-docker.pkg.dev/k8s-artifacts-prod/images
us-central1-docker.pkg.dev/k8s-artifacts-prod/images
us-east1-docker.pkg.dev/k8s-artifacts-prod/images
us-east4-docker.pkg.dev/k8s-artifacts-prod/images
us-east5-docker.pkg.dev/k8s-artifacts-prod/images
us-south1-docker.pkg.dev/k8s-artifacts-prod/images
us-west1-docker.pkg.dev/k8s-artifacts-prod/images
us-west2-docker.pkg.dev/k8s-artifacts-prod/images
```
* The destination registries must be appended with an appropriate "subdir" for the
  sub-project (e.g. src `gcr.io/k8s-staging-foobar` promotes to
  `eu.gcr.io/k8s-artifacts-prod/foobar`).  Exceptions to this are
  extremely rare and must be commented and linked to an issue or a PR with discussion.
* The service account is correct.
* Ensure the filename is `promoter-manifest.yaml`
