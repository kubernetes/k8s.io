-- Purpose: create tables for local temporary ASN data and IP storage and matching

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
  name_with_yaml_name varchar,
  region text
);

create table if not exists company_asn (
  asn varchar,
  name varchar
);
create table if not exists pyasn_ip_asn (
  ip cidr,
  asn int
);
create table if not exists asnproc (
  asn bigint not null primary key
);

create table if not exists peeriingdbnet (
  data jsonb
);

create table if not exists peeriingdbpoc (
  data jsonb
);

create table if not exists ip_ranges (
  ip_prefix cidr,
  service text,
  region text,
  vendor text
);

commit;
