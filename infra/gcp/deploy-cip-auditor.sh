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

# Deploy Cloud Run service named "cip-auditor".

set -o errexit
set -o nounset
set -o pipefail

CLOUD_RUN_SERVICE_NAME="cip-auditor"
SUBSCRIPTION_NAME="cip-auditor-invoker"
SERVICE_ACCOUNT="k8s-infra-gcr-promoter@k8s-artifacts-prod.iam.gserviceaccount.com"

# This sets up the GCP project so that it can be ready to deploy the cip-auditor
# service onto Cloud Run.
this::prepare_env()
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
        "--member=serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-pubsub.iam.gserviceaccount.com" \
        "--role=roles/iam.serviceAccountTokenCreator"
}

this::deploy_cip_auditor()
{
    # Deploy the auditor. The "--update-env-vars" is critical as it points to
    # the reference set of official promoter manifests to validate GCR changes
    # against. Note that there is no need to specify the
    # [{asia,eu,us}.]gcr.io/k8s-artifacts-prod GCR (which we want to audit),
    # because the "gcr" Pub/Sub topic on the project will automatically pick up
    # changes seen in [{asia,eu,us}.]gcr.io/k8s-artifacts-prod.
    gcloud run deploy "${CLOUD_RUN_SERVICE_NAME}" \
        --image="us.gcr.io/k8s-artifacts-prod/artifact-promoter/cip-auditor@sha256:${CIP_AUDITOR_DIGEST}" \
        --update-env-vars="CIP_AUDIT_MANIFEST_REPO_URL=https://github.com/kubernetes/k8s.io,CIP_AUDIT_MANIFEST_REPO_BRANCH=master,CIP_AUDIT_MANIFEST_REPO_MANIFEST_DIR=k8s.gcr.io,CIP_AUDIT_GCP_PROJECT_ID=k8s-artifacts-prod" \
        --platform=managed \
        --no-allow-unauthenticated \
        --region=us-central1 \
        --project="${PROJECT_ID}" \
        --service-account="${SERVICE_ACCOUNT}"
}

this::finish_env()
{
    # Allow SERVICE_ACCOUNT to invoke the Cloud Run instance.
    gcloud \
		run \
		services \
		add-iam-policy-binding \
		"${CLOUD_RUN_SERVICE_NAME}" \
		"--member=serviceAccount:${SERVICE_ACCOUNT}" \
		"--role=roles/run.invoker" \
		"--platform=managed" \
        --project="${PROJECT_ID}" \
		"--region=us-central1"

	# Create subscription if it doesn't exist yet.
	if ! gcloud pubsub subscriptions list --format='value(name)' --project="${PROJECT_ID}" \
        | grep "projects/${PROJECT_ID}/subscriptions/${SUBSCRIPTION_NAME}"; then
        # Find HTTPS push endpoint (invocation endpoint) of the auditor. During
        # experiments, it has been shown that this endpoint does not change (even if
        # the Cloud Run service is deleted and redeployed), as the endpoint is
        # composed of the CLOUD_RUN_SERVICE_NAME and a unique hash that is tied to
        # the PROJECT_ID. E.g., a sample endpoint is
        # "https://cip-auditor-test-hkgjm7emua-uc.a.run.app", where presumably
        # "cip-auditor-test" is the CLOUD_RUN_SERVICE_NAME and "hkgjm7emua-uc" is a
        # UUID tied to a project.
        local auditor_endpoint
        auditor_endpoint=$(gcloud \
            run \
            services \
            describe \
            "${CLOUD_RUN_SERVICE_NAME}" \
            "--platform=managed" \
            "--format=value(status.url)" \
            --project="${PROJECT_ID}" \
            "--region=us-central1")

        gcloud \
            pubsub \
            subscriptions \
            create \
            "${SUBSCRIPTION_NAME}" \
            "--topic=gcr" \
            "--expiration-period=never" \
            "--push-auth-service-account=${SERVICE_ACCOUNT}" \
            "--push-endpoint=${auditor_endpoint}" \
            --project="${PROJECT_ID}"
    fi
}

this::usage()
{
    echo >&2 "Usage: $0 [GCP_PROJECT_ID] [GCP_PROJECT_NUMBER] [CIP_AUDITOR_DIGEST]"
    exit 1
}

this::main()
{
    if (( $# != 3 )); then
        this::usage
    fi

    for arg; do
        if [[ -z "$arg" ]]; then
            this::usage
        fi
    done

    PROJECT_ID="$1"
    PROJECT_NUMBER="$2"
    CIP_AUDITOR_DIGEST="$3"

    this::prepare_env
    this::deploy_cip_auditor
}

this::main "$@"
