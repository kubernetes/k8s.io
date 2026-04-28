## Add company name to vendor
SELECT A.asn, cidr_ip, start_ip, end_ip, start_ip_int, end_ip_int,name_with_yaml_name FROM ( SELECT asn, cidr_ip, start_ip, end_ip, start_ip_int, end_ip_int FROM `${GCP_BIGQUERY_DATASET_WITH_DATE}.vendor`) A LEFT OUTER JOIN ( SELECT asn, name_with_yaml_name FROM `${GCP_BIGQUERY_DATASET_WITH_DATE}..4_potaroo_with_yaml_name_subbed`) B ON A.asn=B.asn
