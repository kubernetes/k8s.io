#!/bin/bash

## Get single clientip as int.
GCP_BIGQUERY_DATASET_WITH_DATE="${GCP_BIGQUERY_DATASET}_$(date +%Y%m%d)"
export GCP_BIGQUERY_DATASET_WITH_DATE

if [ -n "${GCP_BIGQUERY_DATASET_LOGS:-}" ]; then
    envsubst < /app/distinct_c_ip_count_logs.sql | bq query --nouse_legacy_sql --replace --destination_table "${GCP_BIGQUERY_DATASET_WITH_DATE}.1_ip_count" > "${BQ_OUTPUT:-/dev/null}" 2>&1
else
    envsubst < /app/distinct_c_ip_count.sql | bq query --nouse_legacy_sql --replace --destination_table "${GCP_BIGQUERY_DATASET_WITH_DATE}.1_ip_count" > "${BQ_OUTPUT:-/dev/null}" 2>&1
fi
envsubst < /app/distinct_ip_int.sql | bq query --nouse_legacy_sql --replace --destination_table "${GCP_BIGQUERY_DATASET_WITH_DATE}.2_ip_int" > "${BQ_OUTPUT:-/dev/null}" 2>&1
envsubst < /app/distinct_ipint_only.sql | bq query --nouse_legacy_sql --replace --destination_table "${GCP_BIGQUERY_DATASET_WITH_DATE}.2a_ip_int" > "${BQ_OUTPUT:-/dev/null}" 2>&1
envsubst < /app/potaroo_extra_yaml_name_column.sql | bq query --nouse_legacy_sql --replace --destination_table "${GCP_BIGQUERY_DATASET_WITH_DATE}.3_potaroo_with_yaml_name_column" > "${BQ_OUTPUT:-/dev/null}" 2>&1
envsubst < /app/potaroo_yaml_name_subbed.sql | bq query --nouse_legacy_sql --replace --destination_table "${GCP_BIGQUERY_DATASET_WITH_DATE}.4_potaroo_with_yaml_name_subbed" > "${BQ_OUTPUT:-/dev/null}" 2>&1
envsubst < /app/vendor_with_company_name.sql | bq query --nouse_legacy_sql --replace --destination_table "${GCP_BIGQUERY_DATASET_WITH_DATE}.5_vendor_with_company_name" > "${BQ_OUTPUT:-/dev/null}" 2>&1
