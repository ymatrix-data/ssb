:EXPLAIN_ANALYZE

select date_part('year', lo_orderdate) as year
     , c_nation
     , sum(lo_revenue - lo_supplycost) as profit
  from :tname
 where c_region = 'AMERICA'
   and s_region = 'AMERICA'
   and p_mfgr in ('MFGR#1', 'MFGR#2')
 group by year
        , c_nation
 order by year asc
        , c_nation asc
;