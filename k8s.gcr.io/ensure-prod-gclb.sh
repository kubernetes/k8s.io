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
PROJECT="k8s-gcr-prod"

# Name for cloud objects (url-map, gclb, etc)
NAME=k8s-prod-artifacts

# Name for the prod bucket
# This must match the prod GCS bucket name
BUCKET_NAME=k8s-prod-artifacts

# Domain name on which we serve artifacts
DOMAIN=artifacts.k8s.io



color 6 "Ensuring project exists: ${PROJECT}"
ensure_project "${PROJECT}"

color 6 "Configuring billing: ${PROJECT}"
ensure_billing "${PROJECT}"

color 6 "Enabling the compute API: ${PROJECT}"
enable_api "${PROJECT}" compute.googleapis.com

color 6 "Reconciling Global Address"
if ! gcloud compute addresses describe --global "${NAME}" >/dev/null 2>&1; then
  gcloud compute addresses create "${NAME}" --description="IP Address for GCLB for binary artifacts" --global
fi
ip_addr=$(gcloud compute addresses describe "${NAME}" --global --format='value(address)')
echo "Address: ${ip_addr}"

color 6 "Reconciling GCLB Backend Bucket"
if ! gcloud compute backend-buckets describe "${NAME}" >/dev/null 2>&1; then
  gcloud compute backend-buckets create "${NAME}" --gcs-bucket-name="${BUCKET_NAME}"
else
  gcloud compute backend-buckets update "${NAME}" --gcs-bucket-name="${BUCKET_NAME}"
fi

color 6 "Reconciling GCLB URL Map"
if ! gcloud compute url-maps describe "${NAME}" >/dev/null 2>&1; then
  gcloud compute url-maps create "${NAME}" --default-backend-bucket="${NAME}"
else
  gcloud compute url-maps set-default-service "${NAME}" --default-backend-bucket="${NAME}"
fi

color 6 "Reconciling GCLB Target HTTP Proxy"
if ! gcloud compute target-http-proxies describe "${NAME}" >/dev/null 2>&1; then
  gcloud compute target-http-proxies create "${NAME}" --url-map="${NAME}"
else
  gcloud compute target-http-proxies update "${NAME}" --url-map="${NAME}"
fi

color 6 "Reconciling GCLB Forwarding Rule for HTTP"
if ! gcloud compute forwarding-rules describe "${NAME}-http" --global >/dev/null 2>&1; then
  gcloud compute forwarding-rules create "${NAME}-http" --target-http-proxy="${NAME}" --ports=80 --address="${ip_addr}" --global
else
  gcloud compute forwarding-rules set-target "${NAME}-http" --target-http-proxy="${NAME}" --global
fi

color 6 "Reconciling GCLB SSL Certificate"
if ! gcloud compute ssl-certificates describe "${NAME}" >/dev/null 2>&1; then
  gcloud beta compute ssl-certificates create "${NAME}" --domains "${DOMAIN}"
fi

color 6 "Reconciling GCLB Target HTTPS Proxy"
if ! gcloud compute target-https-proxies describe "${NAME}" >/dev/null 2>&1; then
  gcloud compute target-https-proxies create "${NAME}" --url-map="${NAME}" --ssl-certificates="${NAME}"
else
  gcloud compute target-https-proxies update "${NAME}" --url-map="${NAME}" --ssl-certificates="${NAME}"
fi

color 6 "Reconciling GCLB Forwarding Rule for HTTPS"
if ! gcloud compute forwarding-rules describe "${NAME}-https" --global >/dev/null 2>&1; then
  gcloud compute forwarding-rules create "${NAME}-https" --target-https-proxy="${NAME}" --ports=443 --address="${ip_addr}" --global
else
  gcloud compute forwarding-rules set-target "${NAME}-https" --target-https-proxy="${NAME}" --global
fi

color 6 "Done"
