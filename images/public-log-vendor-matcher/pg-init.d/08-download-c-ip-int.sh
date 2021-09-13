## Set a timestamp to work with
TIMESTAMP=$(date +%Y%m%d%H%M)
echo $TIMESTAMP > /tmp/my-timestamp.txt
## Dump the entire table to gcs
bq extract \
--destination_format CSV \
${GCP_BIGQUERY_DATASET}_$(date +%Y%m%d).2a_ip_int \
gs://ii_bq_scratch_dump/2a_ip_inti-$TIMESTAMP-*.csv
## Download the files
TIMESTAMP=$(cat /tmp/my-timestamp.txt | tr -d '\n')
mkdir -p /tmp/usage_all_ip_only/
gsutil cp \
gs://ii_bq_scratch_dump/2a_ip_inti-$TIMESTAMP-*.csv \
/tmp/usage_all_ip_only/
## Merge the data
cat /tmp/usage_all_ip_only/*.csv | tail +2 > /tmp/usage_all_ip_only_1.csv
cat /tmp/usage_all_ip_only_1.csv | grep -v c_ip_int > /tmp/usage_all_ip_only.csv
