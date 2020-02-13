#!/usr/bin/env bash
#
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

# Wire up the AUDITOR_SERVICE_NAME to receive events from GCR. This script only
# needs to be run 1x after the first deployment of the auditor, as long as
# AUDITOR_SERVACE_NAME doesn't change. Also, the "ensure-prod-storage.sh" script
# must run before this script, because that script creates both the
# AUDITOR_INVOKER_SVCACCT (used by this script) and the AUDITOR_SVCACCT (used by
# cip-auditor/deploy.sh).
#
# So the sequence should be:
#
# - Run ensure-prod-storage.sh
# - Run deploy.sh
# - Run this script.
#
# Thereafter, new deployments of the auditor only requires running the deploy.sh
# script.

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
. "${SCRIPT_DIR}/lib.sh"

SUBSCRIPTION_NAME="cip-auditor-invoker"

# This sets up the GCP project so that it can be ready to deploy the cip-auditor
# service onto Cloud Run.
prepare_env()
{
    # Enable APIs.
    services=(
        "serviceusage.googleapis.com"
        "cloudresourcemanager.googleapis.com"
        "stackdriver.googleapis.com"
        "clouderrorreporting.googleapis.com"
        "run.googleapis.com"
    )
    for service in "${services[@]}"; do
        gcloud --quiet services enable "${service}" --project="${PROJECT_ID}"
    done

    # Create "gcr" topic if it doesn't exist yet.
    if ! gcloud pubsub topics list --format='value(name)' --project="${PROJECT_ID}" \
        | grep "projects/${PROJECT_ID}/topics/gcr"; then

        gcloud pubsub topics create gcr --project="${PROJECT_ID}"
    fi

    # Allow the Pub/Sub to create auth tokens in the project. This is part of
    # the authentication bridge between the "gcr" Pub/Sub topic and the
    # "--no-allow-unauthenticated" Cloud Run service option.
    gcloud \
        projects \
        add-iam-policy-binding \
        "${PROJECT_ID}" \
        --member="serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-pubsub.iam.gserviceaccount.com" \
        --role=roles/iam.serviceAccountTokenCreator

    # Create subscription if it doesn't exist yet.
    if ! gcloud pubsub subscriptions list --format='value(name)' --project="${PROJECT_ID}" \
        | grep "projects/${PROJECT_ID}/subscriptions/${SUBSCRIPTION_NAME}"; then

        # Find HTTPS push endpoint (invocation endpoint) of the auditor. This
        # URL will never change (part of the service name is baked into it), as
        # per https://cloud.google.com/run/docs/deploying#url.
        local auditor_endpoint
        auditor_endpoint=$(\
            gcloud \
                run \
                services \
                describe \
                "${AUDITOR_SERVICE_NAME}" \
                --platform=managed \
                --format='value(status.url)' \
                --project="${PROJECT_ID}" \
                --region=us-central1)

        if [[ -z "${auditor_endpoint}" ]]; then
            echo >&2 "Please run the cip-auditor/deploy.sh script to first deploy the auditor before running this script."
            exit 1
        fi

        gcloud \
            pubsub \
            subscriptions \
            create \
            "${SUBSCRIPTION_NAME}" \
            --topic=gcr \
            --expiration-period=never \
            --push-auth-service-account="$(svc_acct_email "${PROJECT_ID}" "${AUDITOR_INVOKER_SVCACCT}")" \
            --push-endpoint="${auditor_endpoint}" \
            --project="${PROJECT_ID}"
    fi
}

usage()
{
    echo >&2 "Usage: $0 <GCP_PROJECT_ID> <GCP_PROJECT_NUMBER>"
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
    PROJECT_NUMBER="$2"

    prepare_env
}

main "$@"
