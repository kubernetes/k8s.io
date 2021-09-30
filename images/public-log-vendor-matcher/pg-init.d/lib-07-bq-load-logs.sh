#!/bin/bash
# Purpose: Load the k8s-infra-artifacts-gcslogs logs into the usage_all_raw dataset

if [ -z "${GCP_BIGQUERY_DATASET_LOGS:-}" ]; then
    echo "Using dataset logs, since \$GCP_BIGQUERY_DATASET_LOGS was provided and set to '${GCP_BIGQUERY_DATASET_LOGS:-}'"
    BUCKETS=$(cat /app/buckets.txt)
    for BUCKET in ${BUCKETS[*]}; do
            bq load \
                --autodetect \
                --max_bad_records=2000 \
                "${GCP_BIGQUERY_DATASET}_${PIPELINE_DATE}.usage_all_raw" \
                "gs://k8s-infra-artifacts-gcslogs/${BUCKET}_usage*" >> "${BQ_OUTPUT:-/dev/null}" 2>&1 \
            || true
    done
fi
