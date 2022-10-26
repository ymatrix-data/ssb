:EXPLAIN_ANALYZE

select date_part('year', lo_orderdate) as year
     , c_nation
     , p_category
     , sum(lo_revenue - lo_supplycost) as profit
  from :tname
 where c_region = 'AMERICA'
   and s_region = 'AMERICA'
   and lo_orderdate >= '1997-01-01'
   and lo_orderdate <  '1998-01-01'
   and p_mfgr in ('MFGR#1', 'MFGR#2')
 group by year
        , c_nation
        , p_category
 order by year asc
        , c_nation asc
        , p_category asc
;