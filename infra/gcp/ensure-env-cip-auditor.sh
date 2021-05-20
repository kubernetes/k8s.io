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

readonly CIP_AUDITOR_SUBSCRIPTION_NAME="cip-auditor-invoker"

readonly CIP_AUDITOR_SERVICES=(
    # TODO: used directly, if so what for? if not, dependency of something else?
    clouderrorreporting.googleapis.com
    # TODO: used directly, if so what for? if not, dependency of something else?
    cloudresourcemanager.googleapis.com
    # The GCR auditor runs in Cloud Run
    run.googleapis.com
    # TODO: used directly, if so what for? if not, dependency of something else?
    serviceusage.googleapis.com
    # TODO: used directly, if so what for? if not, dependency of something else?
    stackdriver.googleapis.com
)

# Get the auditor service's Cloud Run push endpoint (the HTTPS endpoint that the
# Pub/Sub subscription listening to the "gcr" topic can hit).
#
#   $1: GCP project ID
function get_push_endpoint() {
    if [ $# != 1 ] || [ -z "$1" ]; then
        echo "${FUNCNAME[0]}(project) requires 1 argument" >&2
        return 1
    fi
    local project="${1}"

    gcloud \
        run services describe \
        "${AUDITOR_SERVICE_NAME}" \
        --platform=managed \
        --format='value(status.url)' \
        --project="${project}" \
        --region=us-central1
}

# This enables the necessary services to use Cloud Run.
#
#   $1: GCP project ID
function enable_services() {
    if [ $# != 1 ] || [ -z "$1" ]; then
        echo "${FUNCNAME[0]}(project) requires 1 argument" >&2
        return 1
    fi
    local project="$1"

    for service in "${CIP_AUDITOR_SERVICES[@]}"; do
        gcloud --project="${project}" services enable "${service}"
    done
}

# This sets up the GCP project so that it can be ready to deploy the cip-auditor
# service onto Cloud Run.
#
#   $1: GCP project ID
#   $2: GCP project number
function link_run_to_pubsub() {
    if [ $# != 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
        echo "${FUNCNAME[0]}(project, project_number) requires 2 arguments" >&2
        return 1
    fi
    local project="$1"
    local project_number="$2"

    local pubsub_serviceagent="service-${project_number}@gcp-sa-pubsub.iam.gserviceaccount.com"
    local auditor_invoker_sa
    auditor_invoker_sa=$(svc_acct_email "${project}" "${AUDITOR_INVOKER_SVCACCT}")

    # Create "gcr" topic if it doesn't exist yet.
    if ! gcloud pubsub topics list --format='value(name)' --project="${project}" \
        | grep "projects/${project}/topics/gcr"; then

        gcloud pubsub topics create gcr --project="${project}"
    fi

    # Allow the Pub/Sub to create auth tokens in the project. This is part of
    # the authentication bridge between the "gcr" Pub/Sub topic and the
    # "--no-allow-unauthenticated" Cloud Run service option.
    ensure_project_role_binding \
        "${project}" \
        "serviceAccount:${pubsub_serviceagent}" \
        "roles/iam.serviceAccountTokenCreator"

    # Create subscription if it doesn't exist yet.
    if ! gcloud pubsub subscriptions list --format='value(name)' --project="${project}" \
        | grep "projects/${project}/subscriptions/${CIP_AUDITOR_SUBSCRIPTION_NAME}"; then

        # Find HTTPS push endpoint (invocation endpoint) of the auditor. This
        # URL will never change (part of the service name is baked into it), as
        # per https://cloud.google.com/run/docs/deploying#url.
        local auditor_endpoint
        auditor_endpoint=$(get_push_endpoint "${project}")

        gcloud \
            pubsub subscriptions create \
            "${CIP_AUDITOR_SUBSCRIPTION_NAME}" \
            --topic=gcr \
            --expiration-period=never \
            --push-auth-service-account="${auditor_invoker_sa}"\
            --push-endpoint="${auditor_endpoint}" \
            --project="${project}"
    fi
}

# This creates a dummy (NOP) Cloud Run service that shares the same
# AUDITOR_SERVICE_NAME as the real production deployments. The point is to
# create a Cloud Run endpoint (https:// URL) that can be used in the rest of
# this script (as auditor_endpoint).
function create_dummy_endpoint() {
    if [ $# != 1 ] || [ -z "$1" ]; then
        echo "${FUNCNAME[0]}(project) requires 1 argument" >&2
        return 1
    fi
    local project="${1}"

    local serviceaccount
    serviceaccount="$(svc_acct_email "${project}" "${AUDITOR_SVCACCT}")"

    gcloud run deploy "${AUDITOR_SERVICE_NAME}" \
        --image="gcr.io/cloudrun/hello" \
        --platform=managed \
        --no-allow-unauthenticated \
        --region=us-central1 \
        --project="${project}" \
        --service-account="${serviceaccount}"
}

function ensure_cip_auditor_env() {
    local project="${1}"
    local project_number
    project_number=$(gcloud projects describe "${project}" --format "value(projectNumber)")

    echo "Enabling services"
    enable_services "${project}"

    if ! get_push_endpoint "${project}"; then
        echo >&2 "Could not determine push endpoint for the auditor's Cloud Run service."
        echo >&2 "Deploying a dummy image instead to create the Cloud Run endpoint."
        create_dummy_endpoint "${project}"
    fi

    link_run_to_pubsub "${project}" "${project_number}"
}

# We want to run in the artifacts project to get pubsub most easily.
ensure_cip_auditor_env "k8s-artifacts-prod"
