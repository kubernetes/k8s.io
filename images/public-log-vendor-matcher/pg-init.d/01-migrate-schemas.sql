begin;

create table if not exists cust_ip (
  c_ip bigint not null
);

create table if not exists vendor_expanded_int (
  asn text,
  cidr_ip cidr,
  start_ip inet,
  end_ip inet,
  start_ip_int bigint,
  end_ip_int bigint,
  name_with_yaml_name varchar
);

create table company_asn (
  asn varchar,
  name varchar
);
create table pyasn_ip_asn (
  ip cidr,
  asn int
);
create table asnproc (
  asn bigint not null primary key
);

create table peeriingdbnet (
  data jsonb
);

create table peeriingdbpoc (
  data jsonb
);

commit;
