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

# Purpose: Promote all the tables to the un-timestamped dataset

if [ ! "${NO_PROMOTE:-}" = "true" ]; then
    TABLE="7_asn_company_c_ip_lookup"
    echo "Removing table '${GCP_BIGQUERY_DATASET}.$TABLE'"
    bq rm -f "${GCP_BIGQUERY_DATASET}.$TABLE" > "${BQ_OUTPUT:-/dev/null}" 2>&1
    echo "Copying table '${GCP_BIGQUERY_DATASET}_${PIPELINE_DATE}.$TABLE' to '${GCP_BIGQUERY_DATASET}.$TABLE'"
    bq cp --noappend_table --nono_clobber -f "${GCP_BIGQUERY_DATASET}_${PIPELINE_DATE}.$TABLE" "${GCP_BIGQUERY_DATASET}.$TABLE"
else
    echo "Promotion of dataset tables disabled."
fi
