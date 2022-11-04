SELECT
  time_micros,
  A.c_ip,
  c_ip_type,
  c_ip_region,
  cs_method,
  cs_uri,
  sc_status,
  cs_bytes,
  sc_bytes,
  time_taken_micros,
  cs_host,
  cs_referer,
  cs_user_agent,
  s_request_id,
  cs_operation,
  cs_bucket,
  cs_object,
  asn,
  name_with_yaml_name,
  region
FROM
  `${GCP_BIGQUERY_DATASET_WITH_DATE}.usage_all_raw_int` AS A
FULL OUTER JOIN
  `${GCP_BIGQUERY_DATASET_WITH_DATE}.6_ip_range_2_ip_lookup` B
  ON
    A.c_ip_int=B.c_ip
