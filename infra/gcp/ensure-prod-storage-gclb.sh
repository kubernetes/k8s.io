#!/usr/bin/env bash
#
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

# This script creates & configures the GCLB in front of the GCS bucket.

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
. "${SCRIPT_DIR}/lib.sh"

usage() {
    echo "usage: $0" > /dev/stderr
    echo > /dev/stderr
}

if [ $# != 0 ]; then
    usage
    exit 1
fi

# The GCP project name.
PROD_PROJECT="k8s-artifacts-prod"

# Name for cloud objects (url-map, gclb, etc)
NAME=k8s-artifacts-prod

# Name for the prod bucket
# This must match the prod GCS bucket name
BUCKET_NAME=k8s-artifacts-prod

# Domain name on which we serve artifacts
DOMAIN=artifacts.k8s.io

color 6 "Ensuring project exists: ${PROD_PROJECT}"
ensure_project "${PROD_PROJECT}"

color 6 "Enabling the compute API: ${PROD_PROJECT}"
enable_api "${PROD_PROJECT}" compute.googleapis.com

color 6 "Reconciling Global Address"
if ! gcloud --project "${PROD_PROJECT}" compute addresses describe "${NAME}" --global >/dev/null 2>&1; then
  gcloud --project "${PROD_PROJECT}" compute addresses create "${NAME}" --global --description="IP Address for GCLB for binary artifacts"
fi
ip_addr=$(gcloud --project "${PROD_PROJECT}" compute addresses describe "${NAME}" --global --format='value(address)')
echo "Address: ${ip_addr}"

color 6 "Reconciling GCLB Backend Bucket"
if ! gcloud --project "${PROD_PROJECT}" compute backend-buckets describe "${NAME}" >/dev/null 2>&1; then
  gcloud --project "${PROD_PROJECT}" compute backend-buckets create "${NAME}" --gcs-bucket-name="${BUCKET_NAME}"
else
  gcloud --project "${PROD_PROJECT}" compute backend-buckets update "${NAME}" --gcs-bucket-name="${BUCKET_NAME}"
fi

color 6 "Reconciling GCLB URL Map"
if ! gcloud --project "${PROD_PROJECT}" compute url-maps describe "${NAME}" >/dev/null 2>&1; then
  gcloud --project "${PROD_PROJECT}" compute url-maps create "${NAME}" --default-backend-bucket="${NAME}"
else
  gcloud --project "${PROD_PROJECT}" compute url-maps set-default-service "${NAME}" --default-backend-bucket="${NAME}"
fi

color 6 "Reconciling GCLB Target HTTP Proxy"
if ! gcloud --project "${PROD_PROJECT}" compute target-http-proxies describe "${NAME}" >/dev/null 2>&1; then
  gcloud --project "${PROD_PROJECT}" compute target-http-proxies create "${NAME}" --url-map="${NAME}"
else
  gcloud --project "${PROD_PROJECT}" compute target-http-proxies update "${NAME}" --url-map="${NAME}"
fi

color 6 "Reconciling GCLB Forwarding Rule for HTTP"
if ! gcloud --project "${PROD_PROJECT}" compute forwarding-rules describe "${NAME}-http" --global >/dev/null 2>&1; then
  gcloud --project "${PROD_PROJECT}" compute forwarding-rules create "${NAME}-http" --global --target-http-proxy="${NAME}" --ports=80 --address="${ip_addr}"
else
  gcloud --project "${PROD_PROJECT}" compute forwarding-rules set-target "${NAME}-http" --global --target-http-proxy="${NAME}"
fi

color 6 "Reconciling GCLB SSL Certificate"
if ! gcloud --project "${PROD_PROJECT}" compute ssl-certificates describe "${NAME}" >/dev/null 2>&1; then
  gcloud --project "${PROD_PROJECT}" beta compute ssl-certificates create "${NAME}" --domains "${DOMAIN}"
fi

color 6 "Reconciling GCLB Target HTTPS Proxy"
if ! gcloud --project "${PROD_PROJECT}" compute target-https-proxies describe "${NAME}" >/dev/null 2>&1; then
  gcloud --project "${PROD_PROJECT}" compute target-https-proxies create "${NAME}" --url-map="${NAME}" --ssl-certificates="${NAME}"
else
  gcloud --project "${PROD_PROJECT}" compute target-https-proxies update "${NAME}" --url-map="${NAME}" --ssl-certificates="${NAME}"
fi

color 6 "Reconciling GCLB Forwarding Rule for HTTPS"
if ! gcloud --project "${PROD_PROJECT}" compute forwarding-rules describe "${NAME}-https" --global >/dev/null 2>&1; then
  gcloud --project "${PROD_PROJECT}" compute forwarding-rules create "${NAME}-https" --global --target-https-proxy="${NAME}" --ports=443 --address="${ip_addr}"
else
  gcloud --project "${PROD_PROJECT}" compute forwarding-rules set-target "${NAME}-https" --global --target-https-proxy="${NAME}"
fi

color 6 "Done"
