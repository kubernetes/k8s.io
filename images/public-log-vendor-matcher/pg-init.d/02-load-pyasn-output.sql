copy company_asn from '/tmp/potaroo_data.csv' delimiter ',' csv;
copy pyasn_ip_asn from '/tmp/pyAsnOutput.csv' delimiter ',' csv;

-- Split subnet into start and end
select
  asn as asn,
  ip as ip,
  host(network(ip)::inet) as ip_start,
  host(broadcast(ip)::inet) as ip_end
into
  table pyasn_ip_asn_extended
from pyasn_ip_asn;

-- Copy the results to cs
copy (select * from pyasn_ip_asn_extended) to '/tmp/pyasn_expanded_ipv4.csv' csv header;
