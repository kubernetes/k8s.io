#!/bin/bash

# Load table for matching IP to IP ranges
bq load --autodetect "${GCP_BIGQUERY_DATASET}_${PIPELINE_DATE}.6_ip_range_2_ip_lookup" /tmp/match-ip-to-iprange.csv > "${BQ_OUTPUT:-/dev/null}" 2>&1
