-- Copy the customer ip in
copy cust_ip from '/tmp/usage_all_ip_only.csv';
-- Copy pyasn expanded in
copy vendor_expanded_int from '/tmp/expanded_pyasn.csv' (DELIMITER(','));
-- Indexes on the Data we are about to range
create index on vendor_expanded_int (end_ip_int);
create index on vendor_expanded_int (start_ip_int);
create index on cust_ip (c_ip);

copy ( SELECT vendor_expanded_int.cidr_ip, vendor_expanded_int.start_ip, vendor_expanded_int.end_ip, vendor_expanded_int.asn, vendor_expanded_int.name_with_yaml_name, cust_ip.c_ip FROM vendor_expanded_int, cust_ip WHERE cust_ip.c_ip >= vendor_expanded_int.start_ip_int AND cust_ip.c_ip <= vendor_expanded_int.end_ip_int) TO '/tmp/match-ip-to-iprange.csv' CSV HEADER;
