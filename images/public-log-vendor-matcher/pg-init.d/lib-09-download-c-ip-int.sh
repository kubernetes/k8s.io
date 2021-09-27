#!/bin/bash

## Set a timestamp to work with
TIMESTAMP=$(date +%Y%m%d%H%M)
echo "$TIMESTAMP" > /tmp/my-timestamp.txt
## Dump the entire table to gcs
bq extract \
  --destination_format CSV \
  "${GCP_BIGQUERY_DATASET}_${PIPELINE_DATE}.2a_ip_int" \
  "gs://ii_bq_scratch_dump/2a_ip_inti-$TIMESTAMP-*.csv" > "${BQ_OUTPUT:-/dev/null}" 2>&1
## Download the files
TIMESTAMP=$(< /tmp/my-timestamp.txt tr -d '\n')
mkdir -p /tmp/usage_all_ip_only/
gsutil cp \
  "gs://ii_bq_scratch_dump/2a_ip_inti-$TIMESTAMP-*.csv" \
  /tmp/usage_all_ip_only/
## Merge the data
cat /tmp/usage_all_ip_only/*.csv | tail -n +2 > /tmp/usage_all_ip_only_1.csv
< /tmp/usage_all_ip_only_1.csv grep -v c_ip_int > /tmp/usage_all_ip_only.csv
