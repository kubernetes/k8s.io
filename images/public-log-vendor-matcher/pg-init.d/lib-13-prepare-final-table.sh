#!/bin/bash

# Create final table
GCP_BIGQUERY_DATASET_WITH_DATE="${GCP_BIGQUERY_DATASET}_${PIPELINE_DATE}"
export GCP_BIGQUERY_DATASET_WITH_DATE

if [ -n "${GCP_BIGQUERY_DATASET_LOGS:-}" ]; then
    USE_LOGS="_no_logs"
fi
envsubst < /app/join_all_the_things${USE_LOGS}.sql | bq query --nouse_legacy_sql --replace --destination_table "${GCP_BIGQUERY_DATASET}_${PIPELINE_DATE}.7_asn_company_c_ip_lookup" > "${BQ_OUTPUT:-/dev/null}" 2>&1
