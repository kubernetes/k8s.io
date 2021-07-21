#!/usr/bin/env bash

# Copyright 2020 The Kubernetes Authors.
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

# TODO(listx): CONVERT THIS TO TERRAFORM!

# Deploy Cloud Run service named "cip-auditor".
#
# Note: the "ensure-prod-storage.sh" script must run before this one, because
# that script creates the CLOUD_RUN_SERVICE_ACCOUNT we use below.

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
. "${SCRIPT_DIR}/../lib.sh"

deploy_cip_auditor()
{
    # Deploy the auditor. The "--update-env-vars" is critical as it points to
    # the reference set of official promoter manifests to validate GCR changes
    # against. Note that there is no need to specify the
    # [{asia,eu,us}.]gcr.io/k8s-artifacts-prod GCR (which we want to audit),
    # because the "gcr" Pub/Sub topic on the project will automatically pick up
    # changes seen in [{asia,eu,us}.]gcr.io/k8s-artifacts-prod.
    #
    # NOTE: This command is NOT IDEMPOTENT. Re-running it N times with the same
    # args will create N Cloud Run "revisions", each time migrating 100% of new
    # traffic to the newest revision. However, all Cloud Run revisions are
    # recorded with a UUID and shown in the Cloud Run dashboard, and we can
    # always roll back to an earlier revision.
    CLOUD_RUN_SERVICE_ACCOUNT="$(svc_acct_email "${PROJECT_ID}" "${AUDITOR_SVCACCT}")"

    gcloud run deploy "${AUDITOR_SERVICE_NAME}" \
        --image="us.gcr.io/k8s-artifacts-prod/artifact-promoter/cip-auditor@sha256:${CIP_AUDITOR_DIGEST}" \
        --update-env-vars="CIP_AUDIT_MANIFEST_REPO_URL=https://github.com/kubernetes/k8s.io,CIP_AUDIT_MANIFEST_REPO_BRANCH=main,CIP_AUDIT_MANIFEST_REPO_MANIFEST_DIR=k8s.gcr.io,CIP_AUDIT_GCP_PROJECT_ID=k8s-artifacts-prod" \
        --platform=managed \
        --no-allow-unauthenticated \
        --region=us-central1 \
        --project="${PROJECT_ID}" \
        --service-account="${CLOUD_RUN_SERVICE_ACCOUNT}" \
        --min-instances=1 \
        --max-instances=1
}

usage()
{
    echo >&2 "Usage: $0 <GCP_PROJECT_ID> <CIP_AUDITOR_DIGEST>"
    exit 1
}

main()
{
    if (( $# != 2 )); then
        usage
    fi

    for arg; do
        if [[ -z "$arg" ]]; then
            usage
        fi
    done

    PROJECT_ID="$1"
    CIP_AUDITOR_DIGEST="$2"

    deploy_cip_auditor
}

main "$@"
