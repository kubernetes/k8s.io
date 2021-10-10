SELECT DISTINCT c_ip, COUNT(c_ip) AS Total_Count FROM `${GCP_BIGQUERY_DATASET_LOGS}.usage_all_raw` GROUP BY c_ip ORDER BY Total_Count DESC
