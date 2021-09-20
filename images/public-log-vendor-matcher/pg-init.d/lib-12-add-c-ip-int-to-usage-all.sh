#!/bin/bash

GCP_BIGQUERY_DATASET_WITH_DATE="${GCP_BIGQUERY_DATASET}_$(date +%Y%m%d)"
export GCP_BIGQUERY_DATASET_WITH_DATE
if [ -n "${GCP_BIGQUERY_DATASET_LOGS:-}" ]; then
    envsubst < /app/add_c_ip_int_to_usage_all_no_logs.sql | bq query --nouse_legacy_sql --replace --destination_table "${GCP_BIGQUERY_DATASET}_$(date +%Y%m%d).usage_all_raw_int" > "${BQ_OUTPUT:-/dev/null}" 2>&1
else
    envsubst < /app/add_c_ip_int_to_usage_all.sql | bq query --nouse_legacy_sql --replace --destination_table "${GCP_BIGQUERY_DATASET}_$(date +%Y%m%d).usage_all_raw_int" > "${BQ_OUTPUT:-/dev/null}" 2>&1
fi
