-- Purpose: Combine vendor data

-- Copy the customer ip in
copy cust_ip from '/tmp/usage_all_ip_only.csv';
-- Copy pyasn expanded in
copy vendor_expanded_int(asn, cidr_ip, start_ip, end_ip, start_ip_int, end_ip_int, name_with_yaml_name) from '/tmp/expanded_pyasn.csv' (DELIMITER(','));
-- Indexes on the Data we are about to range
create index on vendor_expanded_int (end_ip_int);
create index on vendor_expanded_int (start_ip_int);
create index on cust_ip (c_ip);

-- update the vendor name if matching AWS ip range
update
  vendor_expanded_int
set
  name_with_yaml_name = 'amazon.json'
from
  ip_ranges
where
  vendor_expanded_int.cidr_ip = ip_ranges.ip_prefix
and
  ip_ranges.vendor = 'amazon';

-- add ip regions for aws
update
  vendor_expanded_int
set
  region = ip_ranges.region
from
  ip_ranges
where
  vendor_expanded_int.cidr_ip = ip_ranges.ip_prefix
and
  ip_ranges.vendor = 'amazon';

-- add ip regions for google
update
  vendor_expanded_int
set
  region = ip_ranges.region
from
  ip_ranges
where
  vendor_expanded_int.cidr_ip = ip_ranges.ip_prefix
and
  ip_ranges.vendor = 'google';

-- add ip regions for microsoft
update
  vendor_expanded_int
set
  region = ip_ranges.region
from
  ip_ranges
where
  vendor_expanded_int.cidr_ip = ip_ranges.ip_prefix
and
  ip_ranges.vendor = 'microsoft';

copy ( SELECT vendor_expanded_int.cidr_ip, vendor_expanded_int.start_ip, vendor_expanded_int.end_ip, vendor_expanded_int.asn, vendor_expanded_int.name_with_yaml_name, cust_ip.c_ip, vendor_expanded_int.region FROM vendor_expanded_int, cust_ip WHERE cust_ip.c_ip >= vendor_expanded_int.start_ip_int AND cust_ip.c_ip <= vendor_expanded_int.end_ip_int) TO '/tmp/match-ip-to-iprange.csv' CSV HEADER;
