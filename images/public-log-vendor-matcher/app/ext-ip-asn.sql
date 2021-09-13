SELECT
    asn as asn,
    ip as cidr_ip,
    ip_start as start_ip,
    ip_end as end_ip,
    NET.IPV4_TO_INT64(NET.IP_FROM_STRING(ip_start)) AS start_ip_int,
    NET.IPV4_TO_INT64(NET.IP_FROM_STRING(ip_end)) AS end_ip_int
    FROM `k8s-infra-ii-sandbox.${GCP_BIGQUERY_DATASET_WITH_DATE}.pyasn_ip_asn_extended`
    WHERE regexp_contains(ip_start, r"^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}");
