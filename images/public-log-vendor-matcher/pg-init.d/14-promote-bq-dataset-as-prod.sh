for TABLE in $(bq ls ${GCP_BIGQUERY_DATASET}_$(date +%Y%m%d) | awk '{print $1}' | tail +3 | xargs); do
    echo "Removing table '${GCP_BIGQUERY_DATASET}.$TABLE'"
    bq rm -f "${GCP_BIGQUERY_DATASET}.$TABLE";
    echo "Copying table '${GCP_BIGQUERY_DATASET}_$(date +%Y%m%d).$TABLE' to '${GCP_BIGQUERY_DATASET}.$TABLE'"
    bq cp --noappend_table --nono_clobber -f "${GCP_BIGQUERY_DATASET}_$(date +%Y%m%d).$TABLE" "${GCP_BIGQUERY_DATASET}.$TABLE";
done
