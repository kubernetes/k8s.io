-- Purpose: Merge the Potaroo ASN data with the PeeringDB data for networks and point of contact

copy asnproc from '/tmp/potaroo_asn.txt';

copy peeriingdbnet (data) from '/tmp/peeringdb-tables/net.json' csv quote e'\x01' delimiter e'\x02';
copy peeriingdbpoc (data) from '/tmp/peeringdb-tables/poc.json' csv quote e'\x01' delimiter e'\x02';

copy (
  select distinct asn.asn,
  (net.data ->> 'name') as "name",
  (net.data ->> 'website') as "website",
  (poc.data ->> 'email') as email
  from asnproc asn
  left join peeriingdbnet net on (cast(net.data::jsonb ->> 'asn' as bigint) = asn.asn)
  left join peeriingdbpoc poc on ((poc.data ->> 'name') = (net.data ->> 'name'))
-- where (net.data ->>'website') is not null
-- where (poc.data ->> 'email') is not null
  order by email asc) to '/tmp/peeringdb_metadata.csv' csv;
