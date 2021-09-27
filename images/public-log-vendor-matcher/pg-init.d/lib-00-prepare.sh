#!/bin/bash
set -xeo pipefail

PIPELINE_DATE="${PIPELINE_DATE:-$(date +%Y%m%d)}"
export PIPELINE_DATE

cat << EOF > "$HOME/.bigqueryrc"
credential_file = ${GOOGLE_APPLICATION_CREDENTIALS}
project_id = ${GCP_PROJECT}
EOF

gcloud config set project "${GCP_PROJECT}"

[ -n "${GOOGLE_APPLICATION_CREDENTIALS}" ] && \
  gcloud auth activate-service-account --key-file="${GOOGLE_APPLICATION_CREDENTIALS}"

gcloud auth list

## GET ASN_COMAPNY section
## using https://github.com/ii/org/blob/main/research/asn-data-pipeline/etl_asn_company_table.org
## This will pull a fresh copy, I prefer to use what we have in gs
# curl -s  https://bgp.potaroo.net/cidr/autnums.html | sed -nre '/AS[0-9]/s/.*as=([^&]+)&.*">([^<]+)<\/a> ([^,]+), (.*)/"\1", "\3", "\4"/p'  | head

# Remove the previous data set
bq rm -r -f "${GCP_BIGQUERY_DATASET}_${PIPELINE_DATE}" || true

# initalise a new data set with the given name
bq mk \
    --dataset \
    --description "Kubernetes Public artifact traffic, related to CNCF supporting vendors of k8s infrastructure (${PIPELINE_DATE})" \
    "${GCP_PROJECT}:${GCP_BIGQUERY_DATASET}_${PIPELINE_DATE}"

