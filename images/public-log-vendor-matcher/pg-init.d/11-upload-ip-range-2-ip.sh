bq load --autodetect ${GCP_BIGQUERY_DATASET}_$(date +%Y%m%d).6_ip_range_2_ip_lookup /tmp/match-ip-to-iprange.csv
