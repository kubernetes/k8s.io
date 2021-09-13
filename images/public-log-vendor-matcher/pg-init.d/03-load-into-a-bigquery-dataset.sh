## Load csv to bq
bq load --autodetect "${GCP_BIGQUERY_DATASET}_$(date +%Y%m%d).potaroo_all_asn_name" /tmp/potaroo_asn_companyname.csv asn:integer,companyname:string

## Load a copy of the potaroo_data to bq
# https://github.com/ii/org/blob/main/research/asn-data-pipeline/match-ip-to-ip-range.org
bq load --autodetect "${GCP_BIGQUERY_DATASET}_$(date +%Y%m%d).pyasn_ip_asn_extended" /tmp/pyasn_expanded_ipv4.csv asn:integer,ip:string,ip_start:string,ip_end:string

## Lets go convert the beginning and end into ints
export GCP_BIGQUERY_DATASET_WITH_DATE="${GCP_BIGQUERY_DATASET}_$(date +%Y%m%d)"
envsubst < /app/ext-ip-asn.sql | bq query --nouse_legacy_sql --replace --destination_table "${GCP_BIGQUERY_DATASET}_$(date +%Y%m%d).vendor"

mkdir -p /tmp/vendor

VENDORS=(
    microsoft
    google
    amazon
    alibabagroup
    baidu
    digitalocean
    equinixmetal
    huawei
    tencentcloud
)
## This should be the end of pyasn section, we have results table that covers start_ip/end_ip from fs our requirements
## GET k8s asn yaml using:
## https://github.com/ii/org/blob/main/research/asn-data-pipeline/asn_k8s_yaml.org
## Lets create csv's to import
for VENDOR in ${VENDORS[*]}; do
  curl -s "https://raw.githubusercontent.com/kubernetes/k8s.io/main/registry.k8s.io/infra/meta/asns/${VENDOR}.yaml" \
      | yq e . -j - \
      | jq -r '.name as $name | .redirectsTo.registry as $redirectsToRegistry | .redirectsTo.artifacts as $redirectsToArtifacts | .asns[] | [. ,$name, $redirectsToRegistry, $redirectsToArtifacts] | @csv' \
        > "/tmp/vendor/${VENDOR}_yaml.csv"
  bq load --autodetect "${GCP_BIGQUERY_DATASET}_$(date +%Y%m%d).vendor_yaml" "/tmp/vendor/${VENDOR}_yaml.csv" asn_yaml:integer,name_yaml:string,redirectsToRegistry:string,redirectsToArtifacts:string
done

ASN_VENDORS=(
    amazon
    google
    microsoft
)

## GET Vendor YAML
## https://github.com/ii/org/blob/main/research/asn-data-pipeline/asn_k8s_yaml.org
## TODO: Make this a loop that goes through dates to find a working URL
## curl "https://download.microsoft.com/download/7/1/D/71D86715-5596-4529-9B13-DA13A5DE5B63/ServiceTags_Public_$(date --date='-2 days' +%Y%m%d).json" \
curl "https://download.microsoft.com/download/7/1/D/71D86715-5596-4529-9B13-DA13A5DE5B63/ServiceTags_Public_20210906.json" \
    | jq -r '.values[] | .properties.platform as $service | .properties.region as $region | .properties.addressPrefixes[] | [., $service, $region] | @csv' \
      > /tmp/vendor/microsoft_raw_subnet_region.csv
curl 'https://www.gstatic.com/ipranges/cloud.json' \
    | jq -r '.prefixes[] | [.ipv4Prefix, .service, .scope] | @csv' \
      > /tmp/vendor/google_raw_subnet_region.csv
curl 'https://ip-ranges.amazonaws.com/ip-ranges.json' \
    | jq -r '.prefixes[] | [.ip_prefix, .service, .region] | @csv' \
      > /tmp/vendor/amazon_raw_subnet_region.csv

## Load all the csv
for VENDOR in ${ASN_VENDORS[*]}; do
  bq load --autodetect "${GCP_BIGQUERY_DATASET}_$(date +%Y%m%d).vendor_json" "/tmp/vendor/${VENDOR}_raw_subnet_region.csv" ipprefix:string,service:string,region:string
done

mkdir -p /tmp/peeringdb-tables
PEERINGDB_TABLES=(
    net
    poc
)
for PEERINGDB_TABLE in ${PEERINGDB_TABLES[*]}; do
    curl -sG "https://www.peeringdb.com/api/${PEERINGDB_TABLE}" | jq -c '.data[]' | sed 's,",\",g' > "/tmp/peeringdb-tables/${PEERINGDB_TABLE}.json"
done

# /tmp/potaroo_asn.txt

## placeholder for sql we will need to import asn_only from
