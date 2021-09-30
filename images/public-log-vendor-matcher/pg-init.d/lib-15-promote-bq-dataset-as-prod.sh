#!/bin/bash
# Purpose: Promote all the tables to the un-timestamped dataset

if [ ! "${NO_PROMOTE}" = "true" ]; then
  for TABLE in $(bq ls "${GCP_BIGQUERY_DATASET}_${PIPELINE_DATE}" | awk '{print $1}' | tail +3 | xargs); do
    echo "Removing table '${GCP_BIGQUERY_DATASET}.$TABLE'"
    bq rm -f "${GCP_BIGQUERY_DATASET}.$TABLE" > "${BQ_OUTPUT:-/dev/null}" 2>&1
    echo "Copying table '${GCP_BIGQUERY_DATASET}_${PIPELINE_DATE}.$TABLE' to '${GCP_BIGQUERY_DATASET}.$TABLE'"
    bq cp --noappend_table --nono_clobber -f "${GCP_BIGQUERY_DATASET}_${PIPELINE_DATE}.$TABLE" "${GCP_BIGQUERY_DATASET}.$TABLE" > "${BQ_OUTPUT:-/dev/null}" 2>&1
  done
else
    echo "Promotion of dataset tables disabled."
fi
