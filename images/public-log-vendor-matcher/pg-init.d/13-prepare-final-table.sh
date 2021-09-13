## Get single clientip as int.
export GCP_BIGQUERY_DATASET_WITH_DATE="${GCP_BIGQUERY_DATASET}_$(date +%Y%m%d)"
if [ -n "${GCP_BIGQUERY_DATASET_LOGS:-}" ]; then
    envsubst < /app/join_all_the_things_no_logs.sql | bq query --nouse_legacy_sql --replace --destination_table "${GCP_BIGQUERY_DATASET}_$(date +%Y%m%d).7_asn_company_c_ip_lookup"
else
    envsubst < /app/join_all_the_things.sql | bq query --nouse_legacy_sql --replace --destination_table "${GCP_BIGQUERY_DATASET}_$(date +%Y%m%d).7_asn_company_c_ip_lookup"
fi
