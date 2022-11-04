# Public log asn matcher

A Postgres-based k8s-infra data pipeline that produces BigQuery tables for reviewing Kubernetes Public artifact traffic in DataStudio.

It utilises Postgres for some local querying and the Postgres container image's init folder, where several shell scripts are sourced and SQL queries are run.
The process is split between multiple steps, the steps can be found in the `./pg-init.d` folder in this repo or the `/docker-entrypoint-initdb.d`.

Some scripts call from the `/app` folder, in the folder there are:

- some SQL to run against BigQuery
- some Python scripts for local data management
- a text file containing the names of buckets that container access logs (with `_usage` emitted)

The output is finally loaded in a DataStudio report and reviewed by members [sig-k8s-infra](https://github.com/kubernetes/community/blob/master/sig-k8s-infra/README.md) without PII displayed.

## Flow

1. Kubernetes Public GCS buckets for artifacts are configured to write public access logs to a GCS bucket called `k8s-infra-artifacts-gcslogs` in the `k8s-infra-public-pii` project
2. Data from ASN aggregators (PyASN, Potaroo) is collated in Postgres for matching ASN owners / Companies to IP ranges
3. The ASN data is then loaded into BigQuery
4. Publicly known company vendor ASNs from the k8s.io repo into BigQuery
5. PeeringDB company information is fetched via their API and transformed into Postgres with the Potaroo data before being uploaded to BigQuery
6. The Kubernetes Public GCS logs are then loaded into the _usage_all_raw_ table of the BigQuery dataset
7. Various tables are formed out of the previously loaded data in BigQuery, such as IPs and companies to join things together better
8. The IPs are joined and expanded with the IP ranges from the ASN data, then loaded into the dataset as a table
9. All the data is then linked into a single table
10. Tables are then promoted to the stable _${GCP_BIGQUERY_DATASET}_ table for usage in DataStudio
11. Wait until PID1's cmdline is `postgres` (meaning finished init) then halting Postgres cleanly with `pg_ctl kill quit ${PID_FOR_POSTGRES}`, exiting 0

## Environment variables

| Name                             | Default                    | Description                                                                           |
| -------------------------------- | -------------------------- | ------------------------------------------------------------------------------------- |
| `TZ`                             | ``                         | Container time zone                                                                   |
| `POSTGRES_PASSWORD`              | `postgres`                 | The password to set for Postgres                                                      |
| `GOOGLE_APPLICATION_CREDENTIALS` | ``                         | The path to the GCP service account json key                                          |
| `GCP_PROJECT`                    | `k8s-infra-ii-sandbox`     | The project to target which hosts `${GCP_BIGQUERY_DATASET}` and also will be billed   |
| `GCP_BIGQUERY_DATASET`           | `etl_script_generated_set` | The dataset and basename to write to (appends date)                                   |
| `NO_PROMOTE`                     | ``                         | Disable the promotion of `${GCP_BIGQUERY_DATASET}_${DATE}` to ${GCP_BIGQUERY_DATASET} |
| `ASN_DATA_PIPELINE_RETAIN`       | ``                         | Keeps Postgres running after the job has completed                                    |
| `GCP_BQ_DUMP_BUCKET`             | ``                         | A GCP bucket to dump content from BigQuery                                            |
| `DEBUG_MODE`                     | ``                         | Toggles bash's debug mode                                                             |

## Prepare

Log into gcloud

```bash
gcloud auth login
```

Set the GCP project

```bash
gcloud config set project k8s-infra-ii-sandbox
```

Log into application-default

```bash
gcloud auth application-default login
```

## Running the Pipeline Manually

Run in Docker

```bash
TMP_DIR_ETL=$HOME/.tmp/public-log-asn-matcher-$RANDOM
sudo mkdir -p $TMP_DIR_ETL
sudo chmod 0777 ${TMP_DIR_ETL}
sudo chown -R 999 ~/.config/gcloud # allow for postgres user
docker run \
    -d \
    -e DEBUG_MODE=true \
    -e TZ=$TZ \
    -e POSTGRES_PASSWORD="postgres" \
    -e GCP_PROJECT=k8s-infra-ii-sandbox \
    -e GCP_BIGQUERY_DATASET=etl_script_generated_set \
    -e GCP_BQ_DUMP_BUCKET=ii_bq_scratch_dump \
    -v $HOME/.config/gcloud:/var/lib/postgresql/.config/gcloud \
    -v "${TMP_DIR_ETL}:/tmp" \
    --name public-log-asn-matcher \
    gcr.io/k8s-staging-infra-tools/public-log-asn-matcher
docker logs -f public-log-asn-matcher
```

### Clean up

Change permissions of ~/.config/gcloud back

```bash
sudo chown -R $(id -u) ~/.config/gcloud
```

## Generating the bucket list

A list of buckets is used for their `.*_usage` bucket which stores the public access logs

```bash
./generate-buckets.sh
```

## Run a test build

```bash
TAG="$(date -u '+%Y%m%d')-$(git describe --tags --always --dirty)"
PROJECT="k8s-infra-ii-sandbox"
BUCKET="ii_bq_scratch_dump"

gcloud builds submit \
    --verbosity info \
    --config cloudbuild.yaml \
    --substitutions _TAG="${TAG}",_GIT_TAG="${TAG}" \
    --project ${PROJECT} \
    --gcs-source-staging-dir "gs://${BUCKET}/source" \
    .
```
