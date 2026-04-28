SELECT *, NET.IPV4_TO_INT64(NET.IP_FROM_STRING(c_ip)) AS c_ip_int FROM `${GCP_BIGQUERY_DATASET_LOGS}.usage_all_raw` WHERE REGEXP_CONTAINS(c_ip, r"^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}")
