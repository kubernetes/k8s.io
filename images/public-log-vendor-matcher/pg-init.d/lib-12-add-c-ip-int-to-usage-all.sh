#!/bin/bash

# Load table for matching IP to usage

GCP_BIGQUERY_DATASET_WITH_DATE="${GCP_BIGQUERY_DATASET}_${PIPELINE_DATE}"
export GCP_BIGQUERY_DATASET_WITH_DATE
if [ -n "${GCP_BIGQUERY_DATASET_LOGS:-}" ]; then
    USE_LOGS="_no_logs"
fi
envsubst < /app/add_c_ip_int_to_usage_all${USE_LOGS}.sql | bq query --nouse_legacy_sql --replace --destination_table "${GCP_BIGQUERY_DATASET}_${PIPELINE_DATE}.usage_all_raw_int" > "${BQ_OUTPUT:-/dev/null}" 2>&1
