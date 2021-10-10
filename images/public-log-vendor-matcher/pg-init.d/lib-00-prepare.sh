#!/bin/bash
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

PIPELINE_DATE="${PIPELINE_DATE:-$(date +%Y%m%d)}"
export PIPELINE_DATE

cat << EOF > "$HOME/.bigqueryrc"
credential_file = ${GOOGLE_APPLICATION_CREDENTIALS}
project_id = ${GCP_PROJECT}
EOF

gcloud config set project "${GCP_PROJECT}"

# if using a ServiceAccount
[ -n "${GOOGLE_APPLICATION_CREDENTIALS}" ] && \
  gcloud auth activate-service-account --key-file="${GOOGLE_APPLICATION_CREDENTIALS}"

gcloud auth list

# Remove the previous data set
bq rm -r -f "${GCP_BIGQUERY_DATASET}_${PIPELINE_DATE}" || true

# initalise a new data set with the given name
bq mk \
    --dataset \
    --description "Kubernetes Public artifact traffic, related to CNCF supporting vendors of k8s infrastructure (${PIPELINE_DATE})" \
    "${GCP_PROJECT}:${GCP_BIGQUERY_DATASET}_${PIPELINE_DATE}"

