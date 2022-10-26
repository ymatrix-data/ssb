truncate :tname;

insert into :tname
select
    l.lo_orderkey as lo_orderkey,
    l.lo_linenumber as lo_linenumber,
    l.lo_custkey as lo_custkey,
    l.lo_partkey as lo_partkey,
    l.lo_suppkey as lo_suppkey,
    l.lo_orderdate as lo_orderdate,
    l.lo_orderpriority as lo_orderpriority,
    l.lo_shippriority as lo_shippriority,
    l.lo_quantity as lo_quantity,
    l.lo_extendedprice as lo_extendedprice,
    l.lo_ordtotalprice as lo_ordtotalprice,
    l.lo_discount as lo_discount,
    l.lo_revenue as lo_revenue,
    l.lo_supplycost as lo_supplycost,
    l.lo_tax as lo_tax,
    l.lo_commitdate as lo_commitdate,
    l.lo_shipmode as lo_shipmode,
    c.c_name as c_name,
    c.c_address as c_address,
    c.c_city as c_city,
    c.c_nation :: e_c_nation,
    c.c_region :: e_c_region,
    c.c_phone as c_phone,
    c.c_mktsegment as c_mktsegment,
    s.s_name as s_name,
    s.s_address as s_address,
    s.s_city as s_city,
    s.s_nation :: e_c_nation,
    s.s_region :: e_c_region,
    s.s_phone as s_phone,
    p.p_name as p_name,
    p.p_mfgr :: e_p_mfgr,
    p.p_category as p_category,
    p.p_brand as p_brand,
    p.p_color as p_color,
    p.p_type as p_type,
    p.p_size as p_size,
    p.p_container as p_container
from lineorder as l
inner join customer as c on c.c_custkey = l.lo_custkey
inner join supplier as s on s.s_suppkey = l.lo_suppkey
inner join part as p on p.p_partkey = l.lo_partkey
;
