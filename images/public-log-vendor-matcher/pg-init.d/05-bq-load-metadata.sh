## Load output to bq
bq load --autodetect "${GCP_BIGQUERY_DATASET}_$(date +%Y%m%d).metadata" /tmp/peeringdb_metadata.csv asn:integer,name:string,website:string,email:string
