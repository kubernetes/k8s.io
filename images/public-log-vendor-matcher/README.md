# Public log vendor matcher

A Postgres-based k8s-infra data pipeline that produces BigQuery tables for reviewing Kubernetes Public artifact traffic in DataStudio.

## Flow (WIP)

1. Kubernetes Public GCS buckets for artifacts are configured to write public access logs to a GCS bucket called _k8s-infra-artifacts-gcslogs_ in the _k8s-infra-public-pii_ project
2. Data from ASN aggregators (PyASN, Potaroo) is collated in Postgres for matching ASN owners / Companies to IP ranges
3. The ASN data is then loaded into BigQuery
4. Publicly known company vendor ASNs from the k8s.io repo into BigQuery
5. PeeringDB company information

## Environment variables

| Name                             | Default                    | Description                                                                           |
| -------------------------------- | -------------------------- | ------------------------------------------------------------------------------------- |
| `TZ`                             | ``                         | Container time zone                                                                   |
| `GOOGLE_APPLICATION_CREDENTIALS` | ``                         | The path to the GCP service account json key                                          |
| `GCP_PROJECT`                    | `k8s-infra-ii-sandbox`     | The project to target                                                                 |
| `GCP_BIGQUERY_DATASET`           | `etl_script_generated_set` | The dataset and basename to write to (appends date)                                   |
| `NO_PROMOTE`                     | ``                         | Disable the promotion of `${GCP_BIGQUERY_DATASET}_${DATE}` to ${GCP_BIGQUERY_DATASET} |
| `ASN_DATA_PIPELINE_RETAIN`       | ``                         | Keeps Postgres running after the job has completed                                    |

## Running the Pipeline Manually

Run in Docker

```
TMP_DIR_ETL=$(mktemp -d)
echo "${TMP_DIR_ETL}"
sudo chmod 0777 "${TMP_DIR_ETL}"
sudo chown 999 ~/.config/gcloud # allow for postgres user
docker run \
    -it \
    --rm \
    -e TZ=$TZ \
    -e POSTGRES_PASSWORD="postgres" \
    -e GCP_PROJECT=k8s-infra-ii-sandbox \
    -e GCP_BIGQUERY_DATASET=etl_script_generated_set \
    -v $HOME/.config/gcloud:/var/lib/postgresql/.config/gcloud \
    -v "${TMP_DIR_ETL}:/tmp" \
    public-log-vendor-matcher
```
