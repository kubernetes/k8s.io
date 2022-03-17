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

# Purpose: Load the k8s-infra-artifacts-gcslogs logs into the usage_all_raw dataset

if [ -z "${GCP_BIGQUERY_DATASET_LOGS:-}" ]; then
    echo "Using dataset logs, since \$GCP_BIGQUERY_DATASET_LOGS was provided and set to '${GCP_BIGQUERY_DATASET_LOGS:-}'"
    BUCKETS=$(cat /app/buckets.txt)
    # ensure that array can be expressed
    # shellcheck disable=SC2048
    for BUCKET in ${BUCKETS[*]}; do
            echo "Loading bucket '${BUCKET}_usage'"
            bq load \
                --autodetect \
                --max_bad_records=2000 \
                "${GCP_BIGQUERY_DATASET}_${PIPELINE_DATE}.usage_all_raw" \
                "gs://k8s-infra-artifacts-gcslogs/${BUCKET}_usage*" || true
    done
fi
