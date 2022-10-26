:EXPLAIN_ANALYZE

select date_part('year', lo_orderdate) as year
     , s_city
     , p_brand
     , sum(lo_revenue - lo_supplycost) as profit
  from :tname
 where s_nation = 'UNITED STATES'
   and lo_orderdate >= '1997-01-01'
   and lo_orderdate <  '1998-01-01'
   and p_category = 'MFGR#14'
 group by year
        , s_city
        , p_brand
 order by year asc
        , s_city asc
        , p_brand asc
;