#!/bin/bash
# Copyright 2021 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Purpose: Extract and prepare usage data IPs

## Set a timestamp to work with
TIMESTAMP=$(date +%Y%m%d%H%M)
echo "$TIMESTAMP" > /tmp/my-timestamp.txt
## Dump the entire table to gcs
bq extract \
  --destination_format CSV \
  "${GCP_BIGQUERY_DATASET}_${PIPELINE_DATE}.2a_ip_int" \
  "gs://${GCP_BQ_DUMP_BUCKET}/2a_ip_inti-$TIMESTAMP-*.csv"
## Download the files
TIMESTAMP=$(< /tmp/my-timestamp.txt tr -d '\n')
mkdir -p /tmp/usage_all_ip_only/
gsutil cp \
  "gs://${GCP_BQ_DUMP_BUCKET}/2a_ip_inti-$TIMESTAMP-*.csv" \
  /tmp/usage_all_ip_only/
## Merge the data
cat /tmp/usage_all_ip_only/*.csv | tail -n +2 > /tmp/usage_all_ip_only_1.csv
< /tmp/usage_all_ip_only_1.csv grep -v c_ip_int > /tmp/usage_all_ip_only.csv
