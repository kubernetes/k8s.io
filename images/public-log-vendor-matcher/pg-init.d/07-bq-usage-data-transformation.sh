## Get single clientip as int.
export GCP_BIGQUERY_DATASET_WITH_DATE="${GCP_BIGQUERY_DATASET}_$(date +%Y%m%d)"
if [ -n "${GCP_BIGQUERY_DATASET_LOGS:-}" ]; then
    envsubst < /app/distinct_c_ip_count_logs.sql | bq query --nouse_legacy_sql --replace --destination_table "${GCP_BIGQUERY_DATASET_WITH_DATE}.1_ip_count"
else
    envsubst < /app/distinct_c_ip_count.sql | bq query --nouse_legacy_sql --replace --destination_table "${GCP_BIGQUERY_DATASET_WITH_DATE}.1_ip_count"
fi
envsubst < /app/distinct_ip_int.sql | bq query --nouse_legacy_sql --replace --destination_table "${GCP_BIGQUERY_DATASET_WITH_DATE}.2_ip_int"
envsubst < /app/distinct_ipint_only.sql | bq query --nouse_legacy_sql --replace --destination_table "${GCP_BIGQUERY_DATASET_WITH_DATE}.2a_ip_int"
envsubst < /app/potaroo_extra_yaml_name_column.sql | bq query --nouse_legacy_sql --replace --destination_table "${GCP_BIGQUERY_DATASET_WITH_DATE}.3_potaroo_with_yaml_name_column"
envsubst < /app/potaroo_yaml_name_subbed.sql | bq query --nouse_legacy_sql --replace --destination_table "${GCP_BIGQUERY_DATASET_WITH_DATE}.4_potaroo_with_yaml_name_subbed"
envsubst < /app/vendor_with_company_name.sql | bq query --nouse_legacy_sql --replace --destination_table "${GCP_BIGQUERY_DATASET_WITH_DATE}.5_vendor_with_company_name"
