# Kubernetes Artifacts

This directory contains manifests that are used to perform artifact/file
promotion for the Kubernetes project.

- [Ownership](#ownership)
- [Staging buckets](#staging-buckets)
  - [Creating staging projects](#creating-staging-projects)
    - [Create a Google Group](#create-a-google-group)
    - [Create initial manifests](#create-initial-manifests)
    - [Add to infra tracking](#add-to-infra-tracking)
    - [Actuation](#actuation)
- [Enabling automatic builds](#enabling-automatic-builds)
- [Artifact promotion](#artifact-promotion)

## Ownership

The artifact promoter (and process documentation) is maintained by the
[Release Engineering subproject](https://git.k8s.io/community/sig-release#release-engineering) of SIG Release.

Feedback should be directed to their communication channels.

## Staging buckets

Each "project" (as defined by SIGs/subprojects) that require access to perform
file/artifact promotion to artifacts.k8s.io must have a staging GCP project, as
well as a GCS bucket within that GCP project.

Each staging bucket is governed by a Google Group, which grants push access to
that bucket.

Project owners can push to their staging repository and use the artifact
promoter ([`kpromo`][kpromo]) to promote images to the production serving bucket.

### Creating staging projects

#### Create a Google Group

Follow the instructions [here][google-groups] to create a Google Group to
delegate access to your staging project.

#### Create initial manifests

Create two files:

- `filestores/k8s-staging-<project-name>/filepromoter-manifest.yaml`
- `manifests/k8s-staging-<project-name>/OWNERS`

The `filepromoter-manifest.yaml` file will house the credentials and other
filestore/bucket metadata.

(Look at the existing staging configurations and below for examples.)

```yaml
# google group for gcr.io/k8s-staging-cri-tools is
# k8s-infra-staging-cri-tools@kubernetes.io
filestores:
# STAGING PROJECT
- base: gs://k8s-staging-cri-tools/releases/
  # DESIGNATE THE STAGING PROJECT AS THE PROMOTION SOURCE
  src: true
# PRODUCTION DIRECTORY TO PROMOTE TO
- base: gs://k8s-artifacts-prod/binaries/cri-tools/
  # GCP SERVICE ACCOUNT TO USE FOR PROMOTION
  service-account: k8s-infra-promoter@k8s-artifacts-prod.iam.gserviceaccount.com
```

The separation between `filepromoter-manifest.yaml` and the file manifests that
will exist in the `manifests/` directory is to prevent a single PR from
modifying the source registry information as well as the artifact/file/release
information.

Any changes to the `filestores/` directory is expected to be one-time only
during project setup.

Be sure to add the project owners to the
`manifests/k8s-staging-<project-name>/OWNERS` file to increase the number of
people who can approve new artifacts for promotion on behalf of your project.

#### Add to infra tracking

Add the project name to the `infra.staging.projects` list defined in
[`infra/gcp/infra.yaml`][infra.yaml]

#### Actuation

Once your PR merges:

- a postsubmit job will create the necessary Google Group
- whoever approved your PR will run [the necessary bash script(s)][staging-bash]
  to create the staging repo

## Enabling automatic builds

TBD

## Artifact promotion

To promote a set of artifacts, follow these steps:

1. Push the artifacts to staging bucket that was created e.g.,
   `gs://k8s-staging-kops`
2. Fork this git repo
3. Follow the instructions [here][generate-manifest] to generate a file
   promotion manifest, which should be placed in
   `manifests/k8s-staging-<project-name>/<manifest-name>.yaml`. A simple
   convention to follow is using the release's tag as the manifest filename
   e.g., `manifests/k8s-staging-<project-name>/<release-version>.yaml`
4. Create a PR to this git repo for your changes.
5. The PR should trigger a [`pull-k8sio-file-promo` presubmit job][presubmit]
   which will validate and dry-run your changes; check that the `k8s-ci-robot`
   responds 'Job succeeded' for it.
6. Merge the PR. The artifacts will be promoted by one of two jobs
   1. [`post-k8sio-file-promo`][postsubmit] is a postsubmit job that runs
      immediately after merge
   1. [`ci-k8sio-file-promo`][periodic] is a periodic job that runs on a
      schedule (currently every 4 hours)
7. Published artifacts will appear artifacts.k8s.io

[generate-manifest]: https://sigs.k8s.io/promo-tools/cmd/kpromo#generating-a-file-promotion-manifest
[google-groups]: /groups/README.md
[infra.yaml]: /infra/gcp/infra.yaml
[kpromo]: https://sigs.k8s.io/promo-tools/cmd/kpromo
[periodic]: https://prow.k8s.io/job-history/gs/kubernetes-jenkins/logs/ci-k8sio-file-promo
[postsubmit]: https://prow.k8s.io/job-history/gs/kubernetes-jenkins/logs/post-k8sio-file-promo
[presubmit]: https://prow.k8s.io/job-history/gs/kubernetes-jenkins/pr-logs/directory/pull-k8sio-file-promo
[staging-bash]: /infra/gcp/bash/ensure-staging-storage.sh
