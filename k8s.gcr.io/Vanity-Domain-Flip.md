# The Problem

Currently, `k8s.gcr.io` is a vanity domain that points to
`gcr.io/google-containers` (Google-owned and managed). This is a problem because
`k8s.gcr.io` is an alias used throughut the Kubernetes codebase. As Kubernetes
is a community-owned project, `k8s.gcr.io` should instead point to a
community-controlled repo.

# The Solution

The community has created a new repo called `{asia,eu,us}.gcr.io/k8s-artifacts-prod`, and it
has been agreed that the community should use it as the new place to push
production images (instead of `gcr.io/google-containers`). **We can solve the
above problem by flipping the vanity domain (`k8s.gcr.io`) from
`gcr.io/google-containers` to `{asia,eu,us}.gcr.io/k8s-artifacts-prod`**. This way, no change
needs to be made in the Kubernetes codebase.

The minimum prerequisite is that the existing images in `google-containers` must
be copied into `k8s-artifacts-prod` in order to ensure that the domain flip
happens transparently without incurring any interruptions. However there are
other infrastructural improvements that the community has designed, such as
explicit backups, disaster recovery, and also auditing and alerting.

The rest of this document explains the infrastructural improvements surrounding
`{asia,eu,us}.gcr.io/k8s-artifacts-prod`.

# How New Images Get Promoted (Pushed) to Production

To get new images into the old `gcr.io/google-containers`, a Googler must approve a
change in Google's private repository.

On the other hand, the new `{asia,eu,us}.gcr.io/k8s-artifacts-prod` is integrated with a
publicly-visible GitHub repository, named [k8s.io][k8sio]. The [promoter][CIP]
watches this repository for changes and promotes images. In addition, a system
of setting up staging repos, and promoting from them into
`{asia,eu,us}.gcr.io/k8s-artifacts-prod` has been [created][staging-subproject] so that owners of
subprojects in the community can take control of how their images are released.

## The Promoter (cip)

The [Container Image Promoter][CIP] (henceforth "the promoter") is the OSS
rewrite of the [promoter used internally within Google][internal-promoter]. It
works by reading in a set of promoter manifests (YAMLs) that describe the
desired state of a Docker registry's image contents, and proceeds to copy in any
missing images. Currently the toplevel `k8s.gcr.io` directory at the [k8s.io
Github repo][k8sio] defines such a set of promoter manifests.

## Prow Integration

The act of invoking the promoter as a postsubmit against the k8s.io repo is done
by [Prow][prow], as the `post-k8sio-cip` Prow job. There are other Prow jobs
that integrate with the promoter, and the ones relevant to this doc are outlined
in the table below:

- [`post-k8sio-cip`](https://github.com/kubernetes/test-infra/tree/master/config/jobs/kubernetes/test-infra/test-infra-trusted.yaml) ([logs](https://prow.k8s.io/job-history/kubernetes-jenkins/logs/post-k8sio-cip))
  Postsubmit job against k8s.io repo holding promoter manifests. The promoter
  manifests here are those that promote from the various staging subproject
  repos to `{asia,eu,us}.gcr.io/k8s-artifacts-prod/<subproject>/<image>`. It uses the
  `k8s-infra-gcr-promoter@k8s-artifacts-prod.iam.gserviceaccount.com` service
  account to write to `{asia,eu,us}.gcr.io/k8s-artifacts-prod`. For all
  intents and purposes, **this is the gatekeeper for new images going into
  `k8s-artifacts-prod`**.
- [`ci-k8sio-cip`](https://github.com/kubernetes/test-infra/tree/master/config/jobs/kubernetes/test-infra/test-infra-trusted.yaml) ([logs](https://prow.k8s.io/job-history/kubernetes-jenkins/logs/ci-k8sio-cip))
  Like `post-k8sio-cip`, but runs periodically. This is to ensure
  that even if images are accidentally deleted from
  `{asia,eu,us}.gcr.io/k8s-artifacts-prod`, they are automatically copied back. It also
  acts as a kind of sanity check, to ensure that the promoter can run at all.
- [`ci-k8sio-backup`](https://github.com/kubernetes/test-infra/tree/master/config/jobs/kubernetes/test-infra/test-infra-trusted.yaml) ([logs](https://prow.k8s.io/job-history/kubernetes-jenkins/logs/ci-k8sio-backup))
  Runs an hourly backup of all GCR images in
  `{asia,eu,us}.gcr.io/k8s-artifacts-prod` to
  `{asia,eu,us}.gcr.io/k8s-artifacts-prod-bak/YEAR/MONTH/DAY/HOUR/...`.
- [`pull-k8sio-cip`](https://github.com/kubernetes/test-infra/tree/master/config/jobs/kubernetes/sig-release/cip/container-image-promoter.yaml) ([logs](https://prow.k8s.io/job-history/kubernetes-jenkins/logs/pull-k8sio-cip))
  Dry run version of `post-k8sio-cip`. It is run as a presubmit
  check to any PR against [k8s.io Github repo][k8sio]. In particular, it
  catches things like tag moves (which are disallowed). Unlike
  `post-k8sio-cip`, it does not run in the trusted cluster, because it does
  not need to use prod credentials (in fact, it doesn't use any creds).
- [`pull-cip-e2e`](https://github.com/kubernetes/test-infra/tree/master/config/jobs/kubernetes/sig-release/cip/container-image-promoter.yaml) ([logs](https://prow.k8s.io/job-history/kubernetes-jenkins/logs/pull-cip-e2e))
  Runs an [E2E][CIP-e2e] [test][CIP-e2e-promotion] for changes to the promoter source code. This
  test checks that the promoter can promote images (its main purpose). It uses
  the `k8s-infra-gcr-promoter@k8s-cip-test-prod.iam.gserviceaccount.com`
  service account to use the `k8s-cip-test-prod` GCP project resources for its
  test cases (creation/deletion of GCR images, etc.).
- [`pull-cip-auditor-e2e`](https://github.com/kubernetes/test-infra/tree/master/config/jobs/kubernetes/sig-release/cip/container-image-promoter.yaml) ([logs](https://prow.k8s.io/job-history/kubernetes-jenkins/logs/pull-cip-auditor-e2e))
  Like `pull-cip-e2e`, but runs E2E [tests][CIP-e2e-auditor] for the auditing
  mechanism built into the promoter. While the actual auditing mechanism (known
  as "cip-auditor") runs in production in the `k8s-artifacts-prod` project, the
  E2E tests here run in the test-only project named `k8s-gcr-audit-test-prod`
  which is dedicated solely to this purpose. The auditor code lives
  [here][CIP-auditor-code], but the E2E tests for it live
  [here][CIP-e2e-auditor]. The E2E test use the
  `k8s-infra-gcr-promoter@k8s-gcr-audit-test-prod.iam.gserviceaccount.com` GCP
  project resources for creating/deleting Cloud Run services in
  `k8s-gcr-audit-test-prod`, as well as clearing Pub/Sub messages and
  Stackdriver logs to run its tests. Note that it uses a separate GCP project
  than the `pull-cip-e2e`, so that the two tests are isolated from each other.
- [`pull-cip-unit-tests`](https://github.com/kubernetes/test-infra/tree/master/config/jobs/kubernetes/sig-release/cip/container-image-promoter.yaml) ([logs](https://prow.k8s.io/job-history/kubernetes-jenkins/logs/pull-cip-unit-tests))
  This runs unit tests for the promoter codebase, and are part of
  the PR presubmit checks.
- [`pull-cip-lint`](https://github.com/kubernetes/test-infra/tree/master/config/jobs/kubernetes/sig-release/cip/container-image-promoter.yaml) ([logs](https://prow.k8s.io/job-history/kubernetes-jenkins/logs/pull-cip-lint))
  This runs [golangci-lint][golangci-lint] for the promoter
  codebase (which is primarily written in Go).
- [`pull-k8sio-backup`](https://github.com/kubernetes/test-infra/tree/master/config/jobs/kubernetes/sig-release/cip/container-image-promoter.yaml) ([logs](https://prow.k8s.io/job-history/kubernetes-jenkins/logs/pull-k8sio-backup))
  Checks that changes to the [backup scripts][k8sio-backup] are
  valid. Like the `pull-cip-e2e` and `pull-cip-auditor-e2e` jobs, this job
  uses GCP resources to check that the backup scripts work as intended in
  `ci-k8sio-backup`.

## Critical User Journey for Promotion

In order for a user to push to `k8s-artifacts-prod`, they must:

1. Ensure that they have a [subproject staging repo][staging-subproject] (e.g.,
   `gcr.io/k8s-staging-foo` for the `foo` subproject).
2. Add the promotion metadata in the [manifests subdirectory][] in the k8s.io repo.

### Security Restrictions

- **Write-once**: Images promoted to production will NOT be deleted, unless under extreme,
  emergency circumstances that require human supervision (see "Breakglass"
  section below).
- **Immutable tags**: New images added to the promoter manifests cannot use an
  existing tag for the same image. In other words, tags (once created for an
  image) cannot be deleted.
- **Mandatory subproject prefix**: Images must be prefixed in production by the
  name of the subproject. For example, the subproject named `foo` must only push
  images to `{asia,eu,us}.gcr.io/k8s-artifacts-prod/foo/...`.

# Breakglass

Images in `k8s-artifacts-prod` are not normally deletable. For emergencies,
however, you can reach the GCR admins listed in the
`k8s-infra-artifact-admins@kubernetes.io` group [here][groups] who have write
access to GCR.

# Backups

The GCR images in `k8s-artifacts-prod` are backed up every hour. This is done
with the `ci-k8sio-backup` [Prow job][ci-k8sio-backup-code]. All images are
backed up, even legacy images that appeared before the promoter went online that
were not tagged and can only be referenced by their digest.

## Disaster Recovery

In the event that the `k8s-artifacts-prod` GCR is compromised, a human from the
`k8s-infra-artifact-admins@kubernetes.io` group must restore from a known-good
backup snapshot. An example might be:

```
for region in asia eu us; do
    gcrane cp -r ${region}.gcr.io/k8s-artifacts-prod-bak/2020/01/01/00 ${region}.gcr.io/k8s-artifacts-prod
done
```

# Auditing (cip-auditor)

All GCR stateful changes to `{asia,eu,us}.gcr.io/k8s-artifacts-prod` are
detected by the auditor, which runs as a service in Cloud Run in the
`k8s-artifacts-prod` project. If the change fits with the intent of the
[promoter manifests][k8sio], nothing happens. However, if there is a
disagreement, then the GCR transaction is marked as "REJECTED" and an alert is
sent to Stackdriver Error Reporting, where by default it currently notifies the
project owner via email.

The step-by-step process is:

1. An image is created (new tag), deleted, etc on the `k8s-artifacts-prod` GCR.
2. Cloud Pub/Sub message with the stateful change contents is sent over HTTPS to
   the `cip-auditor` service in Cloud Run.
3. `cip-auditor` clones a fresh copy of [promoter manifests][k8sio] at https://github.com/kubernetes/k8s.io.
4. `cip-auditor` checks the Pub/Sub message contents against the promoter manifests.
5. If the message agrees with the promoter manifests, nothing happens.
   Otherwise, a call is made to the Stackdriver Error Reporting API with a stack
   trace with a log of the message contents.

The logs of the auditor are available by using `gcloud`:
```
gcloud \
    logging \
    read \
    --format='value(textPayload)' \
    $(printf "resource.type=project logName=%s resource.labels.project_id=%s" cip-audit-log k8s-artifacts-prod)
```

The configuration for deploying the prod Cloud Run instance is [here][../infra/gcp/deploy-cip-auditor.sh].

## Alerts

The Stackdriver Error Reporting leg of the auditing process is responsible for
sending alerts to humans about the rejected GCR change.

Currently, an email is sent to the project owner(s) of the `k8s-artifacts-prod`
GCP project.

## Service Accounts

The auditing mechanism uses 3 service accounts:

1. The Pub/Sub service account, which GCR will use to emit Pub/Sub messages for
   all changes detected in the project's GCR. This is named
   `service-[PROJECT_NUMBER]@gcp-sa-pubsub.iam.gserviceaccount.com`. No
   permissions changes are necessary for this service account (which should
   already exist in the project by default).
2. The Pub/Sub Push service account, which the Pub/Sub subscription will use to
   push messages to the Cloud Run push endpoint. This service account needs the
   `roles/run.invoker` role (Cloud Run checks for this authorization) in order
   to push messages securely to the Cloud Run endpoint.
3. The Cloud Run service account, which the Cloud Run instance will run as. This
   service account only needs those permissions that the auditing mechanism
   needs, which are:
   - `roles/logging.logWriter`
   - `roles/errorreporting.writer`

## Admin

The `k8s-infra-prod-artifact-auditor@kubernetes.io` googlegroup manages the
auditor service. Its members are listed [here](../groups/groups.yaml).

# Glossary

- GCR: Google Container Registry
- GCS: Google Cloud Storage

[CIP]:https://github.com/kubernetes-sigs/k8s-container-image-promoter
[internal-promoter]:go/registry-promoter
[k8sio]:https://github.com/kubernetes/k8s.io/tree/master/k8s.gcr.io
[k8sio-manifests]:https://github.com/kubernetes/k8s.io/tree/master/k8s.gcr.io/manifests
[k8sio-backup]:https://github.com/kubernetes/k8s.io/tree/master/infra/gcp/backup_tools
[staging-subproject]:https://github.com/kubernetes/k8s.io/tree/master/k8s.gcr.io#staging-repos
[prow]:https://github.com/kubernetes/test-infra/tree/master/prow
[golangci-lint]:https://github.com/golangci/golangci-lint
[groups]:https://github.com/kubernetes/k8s.io/blob/master/groups/groups.yaml
[CIP-e2e]:https://github.com/kubernetes-sigs/k8s-container-image-promoter/tree/master/test-e2e
[CIP-e2e-promotion]:https://github.com/kubernetes-sigs/k8s-container-image-promoter/tree/master/test-e2e/cip
[CIP-e2e-auditor]:https://github.com/kubernetes-sigs/k8s-container-image-promoter/tree/master/test-e2e/cip-auditor
[CIP-auditor-code]:https://github.com/kubernetes-sigs/k8s-container-image-promoter/blob/master/lib/audit/auditor.go
[ci-k8sio-backup-code]:https://github.com/kubernetes/test-infra/tree/master/config/jobs/kubernetes/test-infra/test-infra-trusted.yaml
