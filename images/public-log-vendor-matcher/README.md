# Public log vendor matcher

A Postgres-based k8s-infra data pipeline that produces BigQuery tables for reviewing Kubernetes Public artifact traffic in DataStudio.

## Environment variables

| Name                             | Default                                                | Description                                                                           |
| -------------------------------- | ------------------------------------------------------ | ------------------------------------------------------------------------------------- |
| `TZ`                             | ``                                                     | Container time zone                                                                   |
| `GOOGLE_APPLICATION_CREDENTIALS` | ``                                                     | The path to the GCP service account json key                                          |
| `GCP_PROJECT`                    | `k8s-infra-ii-sandbox`                                 | The project to target                                                                 |
| `GCP_SERVICEACCOUNT`             | `asn-etl@k8s-infra-ii-sandbox.iam.gserviceaccount.com` | The GCP service account name                                                          |
| `GCP_BIGQUERY_DATASET`           | `etl_script_generated_set`                             | The dataset and basename to write to (appends date)                                   |
| `NO_PROMOTE`                     | ``                                                     | Disable the promotion of `${GCP_BIGQUERY_DATASET}_${DATE}` to ${GCP_BIGQUERY_DATASET} |
| `ASN_DATA_PIPELINE_RETAIN`       | ``                                                     | Keeps Postgres running after the job has completed                                    |

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
