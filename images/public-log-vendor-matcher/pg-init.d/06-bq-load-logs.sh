## Load logs to bq
if [ -z "${GCP_BIGQUERY_DATASET_LOGS:-}" ]; then
    echo "Using dataset logs, since \$GCP_BIGQUERY_DATASET_LOGS was provided and set to '$GCP_BIGQUERY_DATASET_LOGS'"
    BUCKETS=(
        asia.artifacts.k8s-artifacts-prod.appspot.com
        eu.artifacts.k8s-artifacts-prod.appspot.com
        k8s-artifacts-cni
        k8s-artifacts-cri-tools
        k8s-artifacts-csi
        k8s-artifacts-gcslogs
        k8s-artifacts-kind
        k8s-artifacts-prod
        us.artifacts.k8s-artifacts-prod.appspot.com
    )
    for BUCKET in ${BUCKETS[*]}; do
            bq load --autodetect --max_bad_records=2000 ${GCP_BIGQUERY_DATASET}_$(date +%Y%m%d).usage_all_raw gs://k8s-infra-artifacts-gcslogs/${BUCKET}_usage* || true
    done
fi
