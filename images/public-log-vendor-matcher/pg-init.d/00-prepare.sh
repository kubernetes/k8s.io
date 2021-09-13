#!/bin/bash
set -x

set -eo pipefail
eval "${ASN_DATA_PIPELINE_PREINIT:-}"

PARENTPID=$(ps -o ppid= -p $$)
echo MY PID     :: $$
echo PARENT PID :: $PARENTPID
ps aux

cat << EOF > $HOME/.bigqueryrc
credential_file = ${GOOGLE_APPLICATION_CREDENTIALS}
project_id = ${GCP_PROJECT}
EOF

gcloud config set project "${GCP_PROJECT}"

## This is just to continue testing wile I wait for permissions for the service account
## Use the activate-service-account live once it has permissions
## The container is being run it so it should let me manually do the auth
# gcloud auth login
gcloud auth activate-service-account "${GCP_SERVICEACCOUNT}" --key-file="${GOOGLE_APPLICATION_CREDENTIALS}"

gcloud auth list

## GET ASN_COMAPNY section
## using https://github.com/ii/org/blob/main/research/asn-data-pipeline/etl_asn_company_table.org
## This will pull a fresh copy, I prefer to use what we have in gs
# curl -s  https://bgp.potaroo.net/cidr/autnums.html | sed -nre '/AS[0-9]/s/.*as=([^&]+)&.*">([^<]+)<\/a> ([^,]+), (.*)/"\1", "\3", "\4"/p'  | head

bq ls
# Remove the previous data set
bq rm -r -f "${GCP_BIGQUERY_DATASET}_$(date +%Y%m%d)" || true

# initalise a new data set with the given name
bq mk \
    --dataset \
    --description "etl pipeline dataset for ASN data from CNCF supporting vendors of k8s infrastructure" \
    "${GCP_PROJECT}:${GCP_BIGQUERY_DATASET}_$(date +%Y%m%d)"

if [ ! -f "/tmp/potaroo_data.csv" ]; then
    gsutil cp gs://ii_bq_scratch_dump/potaroo_company_asn.csv  /tmp/potaroo_data.csv
fi

# Strip data to only return ASN numbers
cat /tmp/potaroo_data.csv | cut -d ',' -f1 | sed 's/"//' | sed 's/"//'| cut -d 'S' -f2 | tail +2 > /tmp/potaroo_asn.txt

cat /tmp/potaroo_data.csv | tail +2 | sed 's,^AS,,g' > /tmp/potaroo_asn_companyname.csv

## GET PYASN section
## using https://github.com/ii/org/blob/main/research/asn-data-pipeline/etl_asn_vendor_table.org

## pyasn installs its utils in ~/.local/bin/*
## Add pyasn utils to path (dockerfile?)
## full list of RIB files on ftp://archive.routeviews.org//bgpdata/2021.05/RIBS/
cd /tmp
if [ ! -f "rib.latest.bz2" ]; then
    pyasn_util_download.py --latest
    mv rib.*.*.bz2 rib.latest.bz2
fi
## Convert rib file to .dat we can process
if [ ! -f "ipasn_latest.dat" ]; then
    pyasn_util_convert.py --single rib.latest.bz2 ipasn_latest.dat
fi
## Run the py script we are including in the docker image
python3 /app/ip-from-pyasn.py /tmp/potaroo_asn.txt ipasn_latest.dat /tmp/pyAsnOutput.csv
## This will output pyasnOutput.csv
