#!/bin/sh

set -e
set -x

PROJECT=`gcloud config get-value project`

# Must generally create in same location as GCS buckets, doesn't apply to US but still a good idea!
# https://cloud.google.com/bigquery/docs/batch-loading-data#data-locations
bq mk --location=US --dataset ${PROJECT}:kubernetes_public_logs

bq mk --table --description "Raw logs from GCS" \
  --label pii:yes \
  --norequire_partition_filter \
  --time_partitioning_field request_time \
  --time_partitioning_type DAY \
  ${PROJECT}:kubernetes_public_logs.raw_gcs_logs schemas/raw_gcs_logs


