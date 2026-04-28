#!/bin/bash
# Copyright 2021 The Kubernetes Authors.
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

# Purpose: check environment [variables] and auth, prepare dataset for tables
set -o errexit
set -o nounset
set -o pipefail

require_env() {
  NAME="${1}"
  if [ -z "${!NAME}" ]; then
    echo "Error: env '${NAME}' is empty and required"
    exit 1
  fi
}

require_env GCP_PROJECT
require_env GCP_BIGQUERY_DATASET
require_env GCP_BQ_DUMP_BUCKET

if [ "${DEBUG_MODE:-}" = "true" ]; then
  set -x
fi

PIPELINE_DATE="${PIPELINE_DATE:-$(date +%Y%m%d)}"
export PIPELINE_DATE

cat << EOF > "$HOME/.bigqueryrc"
credential_file = ${GOOGLE_APPLICATION_CREDENTIALS:-}
project_id = ${GCP_PROJECT}
EOF

gcloud config set project "${GCP_PROJECT}"

# if using a ServiceAccount
[ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ] && \
  gcloud auth activate-service-account --key-file="${GOOGLE_APPLICATION_CREDENTIALS}"

gcloud auth list

# Remove the previous data set
bq rm -r -f "${GCP_BIGQUERY_DATASET}_${PIPELINE_DATE}" || true

# initalise a new data set with the given name
bq mk \
    --dataset \
    --description "Kubernetes Public artifact traffic, related to CNCF supporting vendors of k8s infrastructure (${PIPELINE_DATE})" \
    "${GCP_PROJECT}:${GCP_BIGQUERY_DATASET}_${PIPELINE_DATE}"

