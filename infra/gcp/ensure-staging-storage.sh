#!/usr/bin/env bash

# Copyright 2019 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This script is used to create a new "staging" repo in GCR, and a bucket in GCS.
#
# Each sub-project that needs to publish artifacts should have their
# own staging GCR repo & GCS bucket.
#
# Each staging bucket & repo exists in its own GCP project, and is writable by a
# dedicated googlegroup.

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
. "${SCRIPT_DIR}/lib.sh"

function usage() {
    echo "usage: $0 [repo...]" > /dev/stderr
    echo "example:" > /dev/stderr
    echo "  $0 # do all staging repos" > /dev/stderr
    echo "  $0 coredns # just do one" > /dev/stderr
    echo > /dev/stderr
}

PROD_PROJECT="k8s-artifacts-prod"

# NB: Please keep this sorted.
readonly STAGING_PROJECTS=(
    addon-manager
    apisnoop
    artifact-promoter
    autoscaling
    bootkube
    boskos
    build-image
    capi-docker
    capi-kubeadm
    capi-openstack
    capi-vsphere
    ci-images
    cip-test
    cloud-provider-gcp
    cluster-addons
    cluster-api
    cluster-api-aws
    cluster-api-azure
    cluster-api-do
    cluster-api-gcp
    coredns
    cpa
    cri-tools
    csi
    csi-secrets-store
    descheduler
    dns
    e2e-test-images
    etcd
    etcdadm
    examples
    experimental
    external-dns
    git-sync
    infra-tools
    ingress-nginx
    ingressconformance
    k8s-gsm-tools
    kas-network-proxy
    kind
    kops
    kube-state-metrics
    kubeadm
    kubernetes
    kubetest2
    kustomize
    metrics-server
    mirror
    multitenancy
    networking
    nfd
    npd
    provider-aws
    provider-azure
    provider-openstack
    publishing-bot
    releng
    releng-test
    scheduler-plugins
    scl-image-builder
    service-apis
    sig-docs
    sig-storage
    slack-infra
    sp-operator
    storage-migrator
    test-infra
    txtdirect
)

readonly RELEASE_STAGING_PROJECTS=(
    experimental
    kubernetes
    mirror
    releng
)

readonly STAGING_PROJECT_SERVICES=(
    cloudbuild.googleapis.com
    cloudkms.googleapis.com
    containerregistry.googleapis.com
    containerscanning.googleapis.com
    secretmanager.googleapis.com
    storage-component.googleapis.com
)

if [ $# = 0 ]; then
    # default to all staging projects
    set -- "${STAGING_PROJECTS[@]}"
fi

for REPO; do

    if ! (printf '%s\n' "${STAGING_PROJECTS[@]}" | grep -q "^${REPO}$"); then
      color 2 "Skipping unrecognized staging project name: ${REPO}"
      continue
    fi

    color 3 "Configuring staging: ${REPO}"

    (
        # The GCP project name.
        PROJECT="k8s-staging-${REPO}"

        # The group that can write to this staging repo.
        WRITERS="k8s-infra-staging-${REPO}@kubernetes.io"

        # The names of the buckets
        STAGING_BUCKET="gs://${PROJECT}" # used by humans
        GCB_BUCKET="gs://${PROJECT}-gcb" # used by GCB
        ALL_BUCKETS=("${STAGING_BUCKET}" "${GCB_BUCKET}")

        # A short expiration - it can always be raised, but it is hard to lower
        # We expect promotion within 60d, or for testing to "move on", but
        # it is also short enough that people should notice occasionally,
        # and not accidentally think of the staging buckets as permanent.
        AUTO_DELETION_DAYS=60

        # Make the project, if needed
        color 6 "Ensuring project exists: ${PROJECT}"
        ensure_project "${PROJECT}"

        # Enable writers to use the UI
        color 6 "Empowering ${WRITERS} as project viewers"
        ensure_project_role_binding "${PROJECT}" "group:${WRITERS}" "roles/viewer"

        # Enable services for staging projects and their direct dependencies; prune anything else
        color 6 "Ensuring only necessary services are enabled for staging project: ${PROJECT}"
        ensure_only_services "${PROJECT}" "${STAGING_PROJECT_SERVICES[@]}"

        # Enable image promoter access to vulnerability scanning results
        serviceaccount="$(svc_acct_email "${PROD_PROJECT}" "${PROMOTER_VULN_SCANNING_SVCACCT}")"
        color 6 "Empowering ${serviceaccount} to view vulnernability scanning results for project: ${PROJECT}"
        ensure_project_role_binding "${PROJECT}" "serviceAccount:${serviceaccount}" "roles/containeranalysis.occurrences.viewer"

        # Every project gets a GCR repo

        # Push an image to trigger the bucket to be created
        color 6 "Ensuring the registry exists and is readable"
        ensure_gcr_repo "${PROJECT}"

        # Enable GCR admins
        color 6 "Empowering GCR admins"
        empower_gcr_admins "${PROJECT}"

        # Enable GCR writers
        color 6 "Empowering ${WRITERS} to GCR"
        empower_group_to_write_gcr "${WRITERS}" "${PROJECT}"

        # Every project gets some GCS buckets
        for BUCKET in "${ALL_BUCKETS[@]}"; do
          color 3 "Configuring bucket: ${BUCKET}"

          (
              # Create the bucket
              color 6 "Ensuring the bucket exists and is world readable"
              ensure_public_gcs_bucket "${PROJECT}" "${BUCKET}"

              # Set bucket auto-deletion
              color 6 "Ensuring the bucket has auto-deletion of ${AUTO_DELETION_DAYS} days"
              ensure_gcs_bucket_auto_deletion "${BUCKET}" "${AUTO_DELETION_DAYS}"

              # Enable admins on the bucket
              color 6 "Empowering GCS admins"
              empower_gcs_admins "${PROJECT}" "${BUCKET}"

              # Enable writers on the bucket
              color 6 "Empowering ${WRITERS} to GCS"
              empower_group_to_write_gcs_bucket "${WRITERS}" "${BUCKET}"
          ) 2>&1 | indent
        done


        # Enable GCB and Prow to build and push images.

        # Let sub-project writers use GCB.
        color 6 "Empowering ${WRITERS} as GCB editors"
        empower_group_for_gcb "${PROJECT}" "${WRITERS}"

        # Let prow trigger builds and access the scratch bucket
        color 6 "Empowering Prow"
        empower_prow "${PROJECT}" "${GCB_BUCKET}"
    ) 2>&1 | indent

    color 6 "Done"
done

# Special case: Release Managers
color 6 "Configuring special cases for Release Managers"
for repo in "${RELEASE_STAGING_PROJECTS[@]}"; do
    (
        # The GCP project name.
        PROJECT="k8s-staging-${repo}"

        # Enable Release Manager Associates view access to
        # Release Engineering projects
        color 6 "Empowering ${RELEASE_VIEWERS} as project viewers in ${PROJECT}"
        ensure_project_role_binding "${PROJECT}" "group:${RELEASE_VIEWERS}" "roles/viewer"

        # Grant the kubernete-release-test (old staging) GCB service account
        # admin GCR access to the new staging project for Kubernetes releases.
        # This is required for VDF as we need to continue running
        # stages/releases from the old project while publishing container
        # images to new project.
        #
        # ref: https://github.com/kubernetes/release/pull/1230
        if [[ "${PROJECT}" == "k8s-staging-kubernetes" ]]; then
            color 6 "Empowering kubernetes-release-test GCB service account to admin GCR"
            empower_svcacct_to_admin_gcr "648026197307@cloudbuild.gserviceaccount.com" "${PROJECT}"
        fi
    ) 2>&1 | indent
done

# Special case: In order for ci-kubernetes-build to run on k8s-infra-prow-build,
#               it needs write access to gcr.io/k8s-staging-ci-images. For now,
#               we will grant the prow-build service account write access. Longer
#               term we would prefer service accounts per project, and restrictions
#               on which jobs can use which service accounts.
color 6 "Configuring special case for k8s-staging-ci-images"
(
    PROJECT="k8s-staging-ci-images"
    SERVICE_ACCOUNT=$(svc_acct_email "k8s-infra-prow-build" "prow-build")
    empower_svcacct_to_write_gcr "${SERVICE_ACCOUNT}" "${PROJECT}"
)

# Create a gcb-builder-{staging} GCP service account in project k8s-staging-{staging}
# that can trigger GCB within that project. Allow GKE clusters in {prow_project}
# to use this when running as a kubernetes service account of the same name in
# the "test-pods" namespace
# $1: The staging name (e.g. kubetest2)
# $2: The prow project name (e.g. k8s-infra-prow-build)
function ensure_staging_gcb_builder_service_account() {
    if [ $# != 2 -o -z "$1" -o -z "$2" ]; then
        echo "ensure_staging_gcb_builder_service_account(staging, prow_project) requires 2 arguments" >&2
        return 1
    fi

    local staging="$1"
    local prow_project="$2"
    local prow_job_namespace="test-pods"
    local project="k8s-staging-${staging}"
    local sa_name="gcb-builder-${staging}"
    local sa_email="${sa_name}@${project}.iam.gserviceaccount.com"

    ensure_service_account \
      "${project}" \
      "${sa_name}" \
      "used by k8s-infra-prow-build to trigger GCB, write to GCR for ${project}"

    empower_svcacct_to_write_gcr "${sa_email}" "${project}"

    ensure_project_role_binding \
      "${project}" \
      "serviceAccount:${sa_email}" \
      "roles/cloudbuild.builds.builder"

    empower_ksa_to_svcacct \
        "${prow_project}.svc.id.goog[${prow_job_namespace}/${sa_name}]" \
        "${project}" \
        "${sa_email}"
}

# Special case: In order for pull-release-image-* to run on k8s-infra-prow-build,
#               it needs write access to gcr.io/k8s-staging-releng-test. We are
#               wary of what untrusted code is allowed to do, so we don't allow
#               presubmits to run on k8s-infra-prow-build-trusted.
color 6 "Configuring special case for k8s-staging-releng-test"
(
    ensure_staging_gcb_builder_service_account "releng-test" "k8s-infra-prow-build"
)
