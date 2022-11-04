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

# Purpose: Prepare, fetch, and load company data, PyASN data, PeeringDB, and Vendor data

## Load csv to bq
bq load --autodetect "${GCP_BIGQUERY_DATASET}_${PIPELINE_DATE}.potaroo_all_asn_name" /tmp/potaroo_asn_companyname.csv asn:integer,companyname:string

# Load all PyASN data
bq load --autodetect "${GCP_BIGQUERY_DATASET}_${PIPELINE_DATE}.pyasn_ip_asn_extended" /tmp/pyasn_expanded_ipv4.csv asn:integer,ip:string,ip_start:string,ip_end:string

## Lets go convert the beginning and end into ints
GCP_BIGQUERY_DATASET_WITH_DATE="${GCP_BIGQUERY_DATASET}_${PIPELINE_DATE}"
export GCP_BIGQUERY_DATASET_WITH_DATE
envsubst < /app/ext-ip-asn.sql | bq query --nouse_legacy_sql --replace --destination_table "${GCP_BIGQUERY_DATASET}_${PIPELINE_DATE}.vendor"

mkdir -p /tmp/vendor

VENDORS=(
    alibabagroup
    amazon
    baidu
    digitalocean
    equinixmetal
    google
    huawei
    microsoft
    tencentcloud
)
## This should be the end of pyasn section, we have results table that covers start_ip/end_ip from fs our requirements
# ensure that array can be expressed
# shellcheck disable=SC2048
for VENDOR in ${VENDORS[*]}; do
  # shellcheck disable=SC2016
  curl -s "https://raw.githubusercontent.com/kubernetes/k8s.io/main/registry.k8s.io/infra/meta/asns/${VENDOR}.yaml" \
      | yq -r '.name as $name | .redirectsTo.registry as $redirectsToRegistry | .redirectsTo.artifacts as $redirectsToArtifacts | .asns[] | [. ,$name, $redirectsToRegistry, $redirectsToArtifacts] | @csv' \
        > "/tmp/vendor/${VENDOR}_yaml.csv"
  bq load --autodetect "${GCP_BIGQUERY_DATASET}_${PIPELINE_DATE}.vendor_yaml" "/tmp/vendor/${VENDOR}_yaml.csv" asn_yaml:integer,name_yaml:string,redirectsToRegistry:string,redirectsToArtifacts:string
done

ASN_VENDORS=(
    amazon
    google
    microsoft
)

# Fetch the known IP ranges from vendors that publish them
curl 'https://ip-ranges.amazonaws.com/ip-ranges.json' \
    | jq -r '.prefixes[] | [.ip_prefix, .service, .region, "amazon"] | @csv' \
      > /tmp/vendor/amazon_raw_subnet_region.csv
curl 'https://www.gstatic.com/ipranges/cloud.json' \
    | jq -r '.prefixes[] | [.ipv4Prefix, .service, .scope, "google"] | @csv' \
      > /tmp/vendor/google_raw_subnet_region.csv
MS_SERVICETAG_PUBLIC_REF=$(curl -s https://www.microsoft.com/en-us/download/confirmation.aspx?id=56519 | grep '71D86715-5596-4529-9B13-DA13A5DE5B63' | sed 's,.*href="\(https://.*\.json\).*,\1,g' | tail -n 1)
curl "${MS_SERVICETAG_PUBLIC_REF}" \
    | jq -r '.values[] | .properties.platform as $service | .properties.region as $region | .properties.addressPrefixes[] | [., $service, $region, "microsoft"] | @csv' \
      > /tmp/vendor/microsoft_raw_subnet_region.csv

## Load all the csv
# ensure that array can be expressed
# shellcheck disable=SC2048
for VENDOR in ${ASN_VENDORS[*]}; do
  bq load --autodetect "${GCP_BIGQUERY_DATASET}_${PIPELINE_DATE}.vendor_json" "/tmp/vendor/${VENDOR}_raw_subnet_region.csv" ipprefix:string,service:string,region:string,vendor:string
done

mkdir -p /tmp/peeringdb-tables
PEERINGDB_TABLES=(
    net
    poc
)
# ensure that array can be expressed
# shellcheck disable=SC2048
for PEERINGDB_TABLE in ${PEERINGDB_TABLES[*]}; do
    curl -sG "https://www.peeringdb.com/api/${PEERINGDB_TABLE}" | jq -c '.data[]' | sed 's,",\",g' > "/tmp/peeringdb-tables/${PEERINGDB_TABLE}.json"
done

