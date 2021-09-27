#!/bin/bash

## Set a timestamp to work with
TIMESTAMP=$(date +%Y%m%d%H%M)
echo "$TIMESTAMP" > /tmp/my-timestamp.txt
## Dump the entire table to gcs
bq extract \
  --destination_format CSV \
  "${GCP_BIGQUERY_DATASET}_${PIPELINE_DATE}.5_vendor_with_company_name" \
  "gs://ii_bq_scratch_dump/vendor-$TIMESTAMP-*.csv" > "${BQ_OUTPUT:-/dev/null}" 2>&1
## Download the files
TIMESTAMP=$(< /tmp/my-timestamp.txt tr -d '\n')
mkdir -p /tmp/expanded_pyasn/
gsutil cp \
  "gs://ii_bq_scratch_dump/vendor-$TIMESTAMP-*.csv" \
  /tmp/expanded_pyasn/
## Merge the data
cat /tmp/expanded_pyasn/*.csv | tail -n +2 > /tmp/expanded_pyasn_1.csv
< /tmp/expanded_pyasn_1.csv grep -v cidr_ip > /tmp/expanded_pyasn.csv
