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

# Purpose: Load table for matching IP to usage

GCP_BIGQUERY_DATASET_WITH_DATE="${GCP_BIGQUERY_DATASET}_${PIPELINE_DATE}"
export GCP_BIGQUERY_DATASET_WITH_DATE
if [ -n "${GCP_BIGQUERY_DATASET_LOGS:-}" ]; then
    USE_LOGS="_no_logs"
fi
envsubst < /app/add_c_ip_int_to_usage_all${USE_LOGS:-}.sql | bq query --nouse_legacy_sql --replace --destination_table "${GCP_BIGQUERY_DATASET}_${PIPELINE_DATE}.usage_all_raw_int" >> "${BQ_OUTPUT:-/dev/null}" 2>&1
