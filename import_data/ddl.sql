drop table if exists customer;
create table customer
(
    c_custkey       :dynaint,
    c_name          text,
    c_address       text,
    c_city          text,
    c_nation        text,
    c_region        text,
    c_phone         text,
    c_mktsegment    text,

    c_trailing      :dynaint
)
using ao_column with (compresstype=zstd)
distributed by (c_custkey)
;

drop table if exists lineorder;
create table lineorder
(
    lo_orderkey             :dynaint,
    lo_linenumber           smallint,
    lo_custkey              :dynaint,
    lo_partkey              :dynaint,
    lo_suppkey              :dynaint,
    lo_orderdate            date,
    lo_orderpriority        text,
    lo_shippriority         smallint,
    lo_quantity             smallint,
    lo_extendedprice        :dynaint,
    lo_ordtotalprice        :dynaint,
    lo_discount             smallint,
    lo_revenue              :dynaint,
    lo_supplycost           :dynaint,
    lo_tax                  smallint,
    lo_commitdate           date,
    lo_shipmode             text,

    lo_trailing             :dynaint
)
using ao_column with (compresstype=zstd)
distributed by (lo_orderkey)
;

drop table if exists part;
create table part
(
    p_partkey       :dynaint,
    p_name          text,
    p_mfgr          text,
    p_category      text,
    p_brand         text,
    p_color         text,
    p_type          text,
    p_size          smallint,
    p_container     text,

    p_trailing      :dynaint
)
using ao_column with (compresstype=zstd)
distributed by (p_partkey)
;

drop table if exists supplier;
create table supplier
(
    s_suppkey       :dynaint,
    s_name          text,
    s_address       text,
    s_city          text,
    s_nation        text,
    s_region        text,
    s_phone         text,

    s_trailing      :dynaint
)
using ao_column with (compresstype=zstd)
distributed by (s_suppkey)
;
