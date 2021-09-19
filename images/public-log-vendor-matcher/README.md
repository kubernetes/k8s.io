# Public log vendor matcher

A Postgres-based k8s-infra data pipeline that produces BigQuery tables for reviewing Kubernetes Public artifact traffic in DataStudio.

## Running the Pipeline Manually

Generate a key file for ServiceAccount auth

```
gcloud iam service-accounts keys create /tmp/asn-etl-pipeline-gcp-sa.json --iam-account=asn-etl@k8s-infra-ii-sandbox.iam.gserviceaccount.com
```

Run in Docker

```
TMP_DIR_ETL=$(mktemp -d)
sudo chmod 0777 "${TMP_DIR_ETL}"
sudo chown 999 /tmp/asn-etl-pipeline-gcp-sa.json
docker run \
    -it \
    --rm \
    -e TZ=$TZ \
    -e POSTGRES_PASSWORD="postgres" \
    -e GOOGLE_APPLICATION_CREDENTIALS=/tmp/asn-etl-pipeline-gcp-sa.json \
    -e GCP_PROJECT=k8s-infra-ii-sandbox \
    -e GCP_SERVICEACCOUNT=asn-etl@k8s-infra-ii-sandbox.iam.gserviceaccount.com \
    -e GCP_BIGQUERY_DATASET=etl_script_generated_set \
    -v /tmp/asn-etl-pipeline-gcp-sa.json:/tmp/asn-etl-pipeline-gcp-sa.json:ro \
    -v "${TMP_DIR_ETL}:/tmp" \
    asn-etl-pipeline
echo "${TMP_DIR_ETL}"
```
